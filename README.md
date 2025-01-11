<p align="center">
  <img src="icon.png" alt="Project Logo" width="21%">
</p>

# Dojo for StartOS

Dojo is self-hosted Bitcoin backend server that powers Ashigaru, Samourai Wallet, Sparrow and other light wallets. It's primarily focused on privacy and self-sovereignty. The Start OS version is a stripped down, dependancy based version of the original client maintained by Pavel The Coder. 


**Features**

  - Database to track transactions
  - API endpoints for wallet interactions
  - Choose between bitcoin core and testnet4 for node
  - Choose between electrs and fulcrum for an indexer
  - Handles BIP44, BIP49, and BIP84 address derivation

**Privacy**

  - Manages HD accounts and BIP47 (PayNym) addresses
  - Only backend server that supports wallets that use Ricochet, Stonewall, StonewallX2 and Stowaway

**Target Users**

  - Ashigaru users
  - Sparrow Users
  - Samourai Wallet users
  - Privacy-focused Bitcoin users
  - Self-custody advocates
  - Users wanting to run their own Bitcoin infrastructure

## Dependencies

Install the system dependencies below to build this project by following the instructions in the provided links. You can find instructions on how to set up the appropriate build environment in the [Developer Docs](https://docs.start9.com/latest/developer-docs/packaging).

- [docker](https://docs.docker.com/get-docker)
- [docker-buildx](https://docs.docker.com/buildx/working-with-buildx/)
- [yq](https://mikefarah.gitbook.io/yq)
- [deno](https://deno.land/)
- [make](https://www.gnu.org/software/make/)
- [start-sdk](https://github.com/Start9Labs/start-os/tree/sdk/)

## Build environment
Prepare your StartOS build environment. In this example we are using Ubuntu 20.04.
1. Install docker
```
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker "$USER"
exec sudo su -l $USER
```
2. Set buildx as the default builder
```
docker buildx install
docker buildx create --use
```
3. Enable cross-arch emulated builds in docker
```
docker run --privileged --rm linuxkit/binfmt:v0.8
```
4. Install yq
```
sudo snap install yq
```
5. Install deno
```
sudo snap install deno
```
6. Install essentials build packages
```
sudo apt-get install -y build-essential openssl libssl-dev libc6-dev clang libclang-dev ca-certificates
```
7. Install Rust
```
curl https://sh.rustup.rs -sSf | sh
# Choose nr 1 (default install)
source $HOME/.cargo/env
```
8. Build and install start-sdk 
```
git clone https://github.com/Start9Labs/start-os.git && \
 cd start-os && git submodule update --init --recursive && \
 make sdk
```
Initialize sdk & verify install
```
start-sdk init
start-sdk --version
```
Now you are ready to build the `dojo-startos` package!

## Cloning

Clone the project locally:

```
git clone https://github.com/Start9Labs/dojo-startos-startos.git
cd dojo-startos-startos
git submodule update --init --recursive
```

## Building

To build the `dojo-startos` package for all platforms using start-sdk, run the following command:

```
make
```

To build the `dojo-startos` package for a single platform using start-sdk, run:

```
# for amd64
make x86
```
or
```
# for arm64
make arm
```

## Installing (on StartOS)

Run the following commands to determine successful install:
> :information_source: Change server-name.local to your Start9 server address

```
start-cli auth login
# Enter your StartOS password
start-cli --host https://server-name.local package install dojo.s9pk
```

If you already have your `start-cli` config file setup with a default `host`, you can install simply by running:

```
make install
```

> **Tip:** You can also install the dojo-startos.s9pk using **Sideload Service** under the **System > Manage** section.

### Verify Install

Go to your StartOS Services page, select **Dojo**, configure and start the service. Then, verify its interfaces are accessible.

**Done!** 
