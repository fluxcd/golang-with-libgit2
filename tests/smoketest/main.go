package main

import (
	"C"
	"log"

	"fmt"
	"io/ioutil"
	"os"

	// git2go must be aligned with libgit2 version:
	// https://github.com/libgit2/git2go#which-go-version-to-use
	git2go "github.com/libgit2/git2go/v33"
)
import (
	"bufio"
	"io"
	"net"
	"path/filepath"
	"strings"

	"golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/knownhosts"
)

const keysDir = "/root/smoketest/keys"
const host = "github.com"

// ssh-keyscan -t ecdsa github.com
const knownHost_ecdsa = `# github.com:22 SSH-2.0-babeld-b6e6da7b
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=`

// fingerprints can be validated against:
// https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

// TODO: setup SSH test servers to force and test rsa/ed25519 support
// ssh-keyscan -t rsa github.com
const knownHost_rsa = `# github.com:22 SSH-2.0-babeld-b6e6da7b
github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==`

// ssh-keyscan -t ed25519 github.com
const knownHost_ed25519 = `# github.com:22 SSH-2.0-babeld-b6e6da7b
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl`

func main() {
	fmt.Println("Running tests...")
	os.MkdirAll("/root/tests", 0o755)

	test("HTTPS clone with no options",
		"/root/tests/https-clone-no-options",
		"https://github.com/fluxcd/golang-with-libgit2",
		&git2go.CloneOptions{Bare: true})

	test("SSH clone with rsa key",
		"/root/tests/ssh-clone-rsa",
		"git@github.com:pjbgf/pkg.git",
		&git2go.CloneOptions{
			Bare: true,
			FetchOptions: git2go.FetchOptions{
				RemoteCallbacks: git2go.RemoteCallbacks{
					CredentialsCallback: func(url string, username string, allowedTypes git2go.CredentialType) (*git2go.Credential, error) {
						credential, e := git2go.NewCredentialSSHKey("git", keyPath("id_rsa.pub"), keyPath("id_rsa"), "")
						return credential, e
					},
					CertificateCheckCallback: knownHostsCallback(host, []byte(knownHost_ecdsa)),
				},
			}})

	//TODO: Add test ssh server to remove dependency on having a repo with specific keys registered.
	test("SSH clone with ed25519 key",
		"/root/tests/ssh-clone-ed25519",
		"git@github.com:pjbgf/pkg.git",
		&git2go.CloneOptions{
			Bare: true,
			FetchOptions: git2go.FetchOptions{
				RemoteCallbacks: git2go.RemoteCallbacks{
					CredentialsCallback: func(url string, username string, allowedTypes git2go.CredentialType) (*git2go.Credential, error) {
						credential, e := git2go.NewCredentialSSHKey("git", keyPath("id_ed25519.pub"), keyPath("id_ed25519"), "")
						return credential, e
					},
					CertificateCheckCallback: knownHostsCallback(host, []byte(knownHost_ecdsa)),
				},
			}})
}

func keyPath(keyName string) string {
	return filepath.Join(keysDir, keyName)
}

func test(description, targetDir, repoURI string, cloneOptions *git2go.CloneOptions) {
	fmt.Printf("Test case %q: ", description)
	_, err := git2go.Clone(repoURI, targetDir, cloneOptions)
	if err != nil {
		fmt.Println("FAILED")
		log.Panic(err)
	}

	files, err := ioutil.ReadDir(targetDir)
	if err != nil {
		fmt.Println("FAILED CHECKING TARGET DIR")
		log.Panic(err)
	}
	fmt.Printf("OK (%d files downloaded)\n", len(files))
}

// knownHostCallback returns a CertificateCheckCallback that verifies
// the key of Git server against the given host and known_hosts for
// git.SSH Transports.
func knownHostsCallback(host string, knownHosts []byte) git2go.CertificateCheckCallback {
	return func(cert *git2go.Certificate, valid bool, hostname string) error {
		if cert == nil {
			return fmt.Errorf("no certificate returned for %s", hostname)
		}

		kh, err := parseKnownHosts(string(knownHosts))
		if err != nil {
			return err
		}

		fmt.Printf("Known keys: %d\n", len(kh))

		// First, attempt to split the configured host and port to validate
		// the port-less hostname given to the callback.
		h, _, err := net.SplitHostPort(host)
		if err != nil {
			// SplitHostPort returns an error if the host is missing
			// a port, assume the host has no port.
			h = host
		}

		// Check if the configured host matches the hostname given to
		// the callback.
		if h != hostname {
			return fmt.Errorf("host mismatch: %q %q\n", h, hostname)
		}

		// We are now certain that the configured host and the hostname
		// given to the callback match. Use the configured host (that
		// includes the port), and normalize it, so we can check if there
		// is an entry for the hostname _and_ port.
		h = knownhosts.Normalize(host)
		for _, k := range kh {
			if k.matches(h, cert.Hostkey) {
				return nil
			}
		}
		return fmt.Errorf("hostkey cannot be verified")
	}
}

type knownKey struct {
	hosts []string
	key   ssh.PublicKey
}

func parseKnownHosts(s string) ([]knownKey, error) {
	var knownHosts []knownKey
	scanner := bufio.NewScanner(strings.NewReader(s))
	for scanner.Scan() {
		_, hosts, pubKey, _, _, err := ssh.ParseKnownHosts(scanner.Bytes())
		if err != nil {
			// Lines that aren't host public key result in EOF, like a comment
			// line. Continue parsing the other lines.
			if err == io.EOF {
				continue
			}
			return []knownKey{}, err
		}

		knownHost := knownKey{
			hosts: hosts,
			key:   pubKey,
		}
		knownHosts = append(knownHosts, knownHost)
	}

	if err := scanner.Err(); err != nil {
		return []knownKey{}, err
	}

	return knownHosts, nil
}

func (k knownKey) matches(host string, hostkey git2go.HostkeyCertificate) bool {
	if !containsHost(k.hosts, host) {
		fmt.Println("HOST NOT FOUND")
		return false
	}

	if hostkey.Kind&git2go.HostkeySHA256 > 0 {
		knownFingerprint := ssh.FingerprintSHA256(k.key)
		returnedFingerprint := ssh.FingerprintSHA256(hostkey.SSHPublicKey)

		fmt.Printf("known and found fingerprints:\n%q\n%q\n",
			knownFingerprint,
			returnedFingerprint)
		if returnedFingerprint == knownFingerprint {
			return true
		}
	}

	fmt.Println("host kind not supported")
	return false
}

func containsHost(hosts []string, host string) bool {
	for _, h := range hosts {
		if h == host {
			return true
		}
	}
	return false
}
