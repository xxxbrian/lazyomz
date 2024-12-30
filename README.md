# Usage

1. Default

```bash
curl -sSL https://raw.githubusercontent.com/xxxbrian/lazyomz/refs/heads/main/install.sh | sudo -E bash -s
```

2. Specify the user

```bash
curl -sSL https://raw.githubusercontent.com/xxxbrian/lazyomz/refs/heads/main/install.sh | sudo -E bash -s -- --user <user>
```

3. Use proxy (e.g. https://gh.quick.to)

```bash
curl -sSL https://gh.quick.to/https://raw.githubusercontent.com/xxxbrian/lazyomz/refs/heads/main/install.sh | sudo -E bash -s -- --proxy https://gh.quick.to
```

4. Use proxy and specify the user

```bash
curl -sSL https://gh.quick.to/https://raw.githubusercontent.com/xxxbrian/lazyomz/refs/heads/main/install.sh | sudo -E bash -s -- --user <user> --proxy https://gh.quick.to
```
