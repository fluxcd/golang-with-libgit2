module github.com/fluxcd/golang-with-libgit2/tests/sample

go 1.18

// Use temporary fork that allows for the use of threading to be disabled
// when using git2go.
replace github.com/libgit2/git2go/v33 => github.com/pjbgf/git2go/v33 v33.0.1-nothread

require (
	github.com/fluxcd/pkg/gittestserver v0.5.2
	github.com/fluxcd/pkg/ssh v0.3.2
	github.com/fluxcd/source-controller v0.24.4
	github.com/libgit2/git2go/v33 v33.0.9
	golang.org/x/crypto v0.0.0-20220427172511-eb4f295cb31f
)

require (
	github.com/Microsoft/go-winio v0.5.2 // indirect
	github.com/ProtonMail/go-crypto v0.0.0-20220407094043-a94812496cf5 // indirect
	github.com/acomagu/bufpipe v1.0.3 // indirect
	github.com/emirpasic/gods v1.12.0 // indirect
	github.com/go-git/gcfg v1.5.0 // indirect
	github.com/go-git/go-billy/v5 v5.3.1 // indirect
	github.com/go-git/go-git/v5 v5.4.2 // indirect
	github.com/go-logr/logr v1.2.3 // indirect
	github.com/gofrs/uuid v4.2.0+incompatible // indirect
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/google/go-cmp v0.5.7 // indirect
	github.com/google/gofuzz v1.2.0 // indirect
	github.com/imdario/mergo v0.3.12 // indirect
	github.com/jbenet/go-context v0.0.0-20150711004518-d14ea06fba99 // indirect
	github.com/json-iterator/go v1.1.12 // indirect
	github.com/kevinburke/ssh_config v1.1.0 // indirect
	github.com/mitchellh/go-homedir v1.1.0 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/sergi/go-diff v1.2.0 // indirect
	github.com/sosedoff/gitkit v0.3.0 // indirect
	github.com/xanzy/ssh-agent v0.3.1 // indirect
	golang.org/x/net v0.0.0-20220412020605-290c469a71a5 // indirect
	golang.org/x/sys v0.0.0-20220412211240-33da011f77ad // indirect
	golang.org/x/text v0.3.7 // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	gopkg.in/warnings.v0 v0.1.2 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
	k8s.io/api v0.23.6 // indirect
	k8s.io/apimachinery v0.23.6 // indirect
	k8s.io/klog/v2 v2.50.0 // indirect
	k8s.io/utils v0.0.0-20220210201930-3a6ce19ff2f9 // indirect
	sigs.k8s.io/json v0.0.0-20211208200746-9f7c6b3444d2 // indirect
	sigs.k8s.io/structured-merge-diff/v4 v4.2.1 // indirect
)
