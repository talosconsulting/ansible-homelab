# Ansible

Configures and updates a homelab: zeus (a RHEL 10 server, and an Ansible
controller), Fedora workstations and laptops, and a Windows host. The inventory
and defaults describe these specific machines, so adapt them before running
anything here elsewhere.

| Playbook | Purpose |
| --- | --- |
| `site.yaml` | Configure the Fedora hosts |
| `update.yaml` | Upgrade every host, its firmware and its developer tools |
| `wakeywakey.yaml` | Wake apollo with Wake-on-LAN |
| `morework.yaml` | Keep the stationary hosts awake |
| `jobsdone.yaml` | Let the stationary hosts sleep again |

## Set up the controller (zeus)

These steps take a clean RHEL 10 install to a working `ansible`, `ansible-lint`,
and `yamllint`. Register the system with `subscription-manager` first.

Install uv and Python 3.14. uv comes from EPEL, and Python 3.14 from AppStream:

```bash
sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
sudo dnf install uv python3.14
```

As your normal user, not root, install `ansible-lint`, `ansible-core`, and
`yamllint` as one uv tool:

```bash
uv tool install --python /usr/bin/python3.14 ansible-lint --with-executables-from ansible-core,yamllint
```

- `--with-executables-from ansible-core,yamllint` puts `ansible`,
  `ansible-playbook`, `ansible-galaxy`, and `yamllint` on `PATH`. Without it,
  only `ansible-lint` is available.
- `--python /usr/bin/python3.14` uses the RPM, so `dnf` keeps Python patched.
  The path matters: with `--python 3.14` uv could choose another copy.

Install the collections and the Galaxy role the playbooks use:

```bash
ansible-galaxy collection install -r requirements.yml
ansible-galaxy role install -r requirements.yml
```

Check the result from the root of this repo:

```bash
ansible --version
ansible-lint --version
tests/test_update.sh
```

`ansible --version` should report core 2.22 or newer. Fedora 45 hosts run Python
3.15, and ansible-core 2.21 can't run modules on it.

## Before configuring a Fedora host

`site.yaml` expects these to be set up already:

- SSH access, and passwordless `sudo`, for the user running Ansible.
- [RPM Fusion](https://rpmfusion.org/Configuration) (free and nonfree), for the
  `intel` role.
- On apollo only: `brscan2-0.2.5-1.x86_64.rpm` from Brother in
  `roles/apollo/files/`, and `~/.config/bookmarks.conf` for `bookmarks.sh`.

## Keep it up to date

`update.yaml` upgrades the tool and the installed collections on zeus. To upgrade
the tool by hand:

```bash
uv tool upgrade ansible-lint
```

This also upgrades `ansible-core` and `yamllint`, which are installed with it.

## License

MIT. See `LICENSE`.
