package main

import (
	"C"
	"bufio"
	"bytes"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"fmt"
	"hash"
	"io"
	"io/ioutil"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	// git2go must be aligned with libgit2 version:
	// https://github.com/libgit2/git2go#which-go-version-to-use
	git2go "github.com/libgit2/git2go/v31"

	"github.com/fluxcd/pkg/gittestserver"
	"github.com/fluxcd/pkg/ssh"
	"github.com/fluxcd/source-controller/pkg/git"
	cryptossh "golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/knownhosts"
)

const testsDir = "/root/tests"

func main() {
	fmt.Println("Running tests...")
	os.MkdirAll(testsDir, 0o755)
	defer os.RemoveAll(testsDir)

	repoPath := "test.git"
	server := createTestServer(repoPath)
	if err := server.StartHTTP(); err != nil {
		panic(fmt.Errorf("StartHTTP: %w", err))
	}
	defer server.StopHTTP()

	httpRepoURL := fmt.Sprintf("%s/%s", server.HTTPAddressWithCredentials(), repoPath)
	test("HTTPS clone with no options",
		filepath.Join(testsDir, "/https-clone-no-options"),
		httpRepoURL,
		&git2go.CloneOptions{Bare: true})

	if err := server.ListenSSH(); err != nil {
		panic(fmt.Errorf("listenSSH: %w", err))
	}
	go func() {
		server.StartSSH()
	}()
	defer server.StopSSH()

	u, err := url.Parse(server.SSHAddress())
	if err != nil {
		panic(fmt.Errorf("ssh url Parse: %w", err))
	}
	knownHosts, err := ssh.ScanHostKey(u.Host, 5*time.Second)
	if err != nil {
		panic(fmt.Errorf("scan host key: %w", err))
	}

	sshRepoURL := fmt.Sprintf("%s/%s", server.SSHAddress(), repoPath)

	rsa, err := ssh.NewRSAGenerator(4096).Generate()
	if err != nil {
		panic(fmt.Errorf("generating rsa key: %w", err))
	}
	privateKey := filepath.Join(testsDir, "id_rsa")
	os.WriteFile(privateKey, rsa.PrivateKey, 0o644)
	pubKey := filepath.Join(testsDir, "id_rsa.pub")
	os.WriteFile(pubKey, rsa.PrivateKey, 0o644)

	test("SSH clone with rsa key",
		filepath.Join(testsDir, "/ssh-clone-rsa"),
		sshRepoURL,
		&git2go.CloneOptions{
			Bare: true,
			FetchOptions: &git2go.FetchOptions{
				RemoteCallbacks: git2go.RemoteCallbacks{
					CredentialsCallback: func(url string, username string, allowedTypes git2go.CredentialType) (*git2go.Credential, error) {
						return git2go.NewCredentialSSHKey("git",
							pubKey, privateKey, "")
					},
					CertificateCheckCallback: knownHostsCallback(u.Host, knownHosts),
				},
			},
		})

	ed25519, err := ssh.NewEd25519Generator().Generate()
	if err != nil {
		panic(fmt.Errorf("generating ed25519 key: %w", err))
	}
	privateKey = filepath.Join(testsDir, "id_ed25519")
	os.WriteFile(privateKey, ed25519.PrivateKey, 0o644)
	pubKey = filepath.Join(testsDir, "id_ed25519.pub")
	os.WriteFile(pubKey, ed25519.PrivateKey, 0o644)

	test("SSH clone with ed25519 key",
		filepath.Join(testsDir, "/ssh-clone-ed25519"),
		sshRepoURL,
		&git2go.CloneOptions{
			Bare: true,
			FetchOptions: &git2go.FetchOptions{
				RemoteCallbacks: git2go.RemoteCallbacks{
					CredentialsCallback: func(url string, username string, allowedTypes git2go.CredentialType) (*git2go.Credential, error) {
						return git2go.NewCredentialSSHKey("git",
							pubKey, privateKey, "")
					},
					CertificateCheckCallback: knownHostsCallback(u.Host, knownHosts),
				},
			},
		})

	//TODO: Expand tests to consider supported algorithms/hashes for hostKey verification.
}

func createTestServer(repoPath string) *gittestserver.GitServer {
	fmt.Println("Creating gitserver for SSH tests...")
	server, err := gittestserver.NewTempGitServer()
	if err != nil {
		panic(fmt.Errorf("creating git test server: %w", err))
	}
	defer os.RemoveAll(server.Root())

	server.Auth("test-user", "test-pswd")
	server.AutoCreate()
	server.KeyDir(filepath.Join(server.Root(), "keys"))

	os.MkdirAll("testdata/git/repo", 0o755)
	os.WriteFile("testdata/git/repo/test123", []byte("test..."), 0o644)
	os.WriteFile("testdata/git/repo/test321", []byte("test2..."), 0o644)

	if err = server.InitRepo("testdata/git/repo", git.DefaultBranch, repoPath); err != nil {
		panic(fmt.Errorf("InitRepo: %w", err))
	}
	return server
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
	return func(cert *git2go.Certificate, valid bool, hostname string) git2go.ErrorCode {
		if cert == nil {
			return git2go.ErrorCodeCertificate
		}

		kh, err := parseKnownHosts(string(knownHosts))
		if err != nil {
			return git2go.ErrorCodeCertificate
		}

		fmt.Printf("Known keys: %d\n", len(kh))

		// Check if the configured host matches the hostname given to
		// the callback.
		// In libgit 1.1.* hostname also includes its with port.
		if host != hostname {
			fmt.Printf("host and hostname:\n%q\n%q\n",
				host,
				hostname)
			return git2go.ErrorCodeUser
		}

		// We are now certain that the configured host and the hostname
		// given to the callback match. Use the configured host (that
		// includes the port), and normalize it, so we can check if there
		// is an entry for the hostname _and_ port.
		h := knownhosts.Normalize(host)
		for _, k := range kh {
			if k.matches(h, cert.Hostkey) {
				return git2go.ErrorCodeOK
			}
		}
		return git2go.ErrorCodeCertificate
	}
}

type knownKey struct {
	hosts []string
	key   cryptossh.PublicKey
}

func parseKnownHosts(s string) ([]knownKey, error) {
	var knownHosts []knownKey
	scanner := bufio.NewScanner(strings.NewReader(s))
	for scanner.Scan() {
		_, hosts, pubKey, _, _, err := cryptossh.ParseKnownHosts(scanner.Bytes())
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
		return false
	}

	var fingerprint []byte
	var hasher hash.Hash
	switch {
	case hostkey.Kind&git2go.HostkeySHA256 > 0:
		fingerprint = hostkey.HashSHA256[:]
		hasher = sha256.New()
	case hostkey.Kind&git2go.HostkeySHA1 > 0:
		fingerprint = hostkey.HashSHA1[:]
		hasher = sha1.New()
	case hostkey.Kind&git2go.HostkeyMD5 > 0:
		fingerprint = hostkey.HashMD5[:]
		hasher = md5.New()
	default:
		return false
	}
	hasher.Write(k.key.Marshal())
	return bytes.Equal(hasher.Sum(nil), fingerprint)
}

func containsHost(hosts []string, host string) bool {
	for _, h := range hosts {
		if h == host {
			return true
		}
	}
	return false
}
