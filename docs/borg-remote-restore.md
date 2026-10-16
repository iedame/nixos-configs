# Restoring a large Borg archive from far away

How the 4.8 TB backup of the old 10 TB drive (`wd10tb`) came back from a
Hetzner Storage Box in Helsinki to Aurora in Brazil, in October 2026, and
what to do differently next time. The same approach works for any Borg
repository that is large and far from the machine that needs the data.

In short: Borg from Aurora across the Atlantic was hopelessly slow
(0.15 to 0.7 MB/s), so a temporary Hetzner Cloud server next to the storage
box read the repository at full speed and streamed it to Aurora as many tar
streams side by side. Aurora pulled 20 streams at once over its cable, at
600 to 770 Mbit/s, close to the home connection's speed. The whole archive,
55,519 files, came back in about 21 hours once the final set-up was running
(a day in all, with the false starts), verified file by file, for a few
dollars of server time.

Placeholders below: `<user>` is the storage box's account (`u…`, also in
its host name), `<server>` the cloud server's IPv6 address, `<archive>` the
archive's name. None of them belongs in this repository; the account name
lives only in the agenix secret `aurora/borg-ssh-config`.

## 1. Look before restoring

Aurora reaches the storage box with the backup key and the `borg-<repo>`
aliases of the agenix SSH configuration (`hosts/Aurora/backup.nix`), so
everything here runs as root:

```bash
export BORG_RSH="ssh -F /run/agenix/borg-ssh-config"
```

**Which passphrase.** This repository was Pika Backup's and used the same
passphrase as the `immich` one, not the one 1Password called "pika". When a
passphrase is in doubt, try the known ones without typing them:

```bash
for p in immich home services; do
  echo "== $p"
  BORG_PASSCOMMAND="cat /run/agenix/borg-$p-passphrase" \
    borg list --lock-wait 60 --last 3 ssh://borg-wd10tb/./backups 2>&1 | tail -n 4
done
```

A wrong passphrase given interactively shows only as the prompt coming
back; Borg says nothing else.

**What is in it: the whole file list, once.** Browsing the repository with
`borg mount` from this far is painfully slow (and Dolphin makes it worse by
reading files for previews). One `borg list` writes every path with its
size and date to a text file in a few minutes, which can then be searched
and summed instantly:

```bash
borg list --lock-wait 60 --format "{size:>14} {mtime} {path}{NL}" \
  ssh://borg-wd10tb/./backups::<archive> > ~/wd10tb-files.txt
```

Sizes per folder, from that list (the date takes three fields, so the path
starts after them):

```bash
awk '{ s=$1; p=$0; sub(/^ *[0-9]+ [A-Za-z]+, [0-9-]+ [0-9:]+ /, "", p)
       split(p, a, "/"); t[a[5] "/" a[6]] += s }
     END { for (k in t) printf "%9.1f GB  %s\n", t[k]/1e9, k }' ~/wd10tb-files.txt | sort -rn | head -40
```

(`a[5]` and `a[6]` are the first two folders below
`run/media/haoji/elexfat/`, where Pika had read the drive.)

**What is already back.** Comparing the list with what is on the disk, by
file name and size, and by size alone for large files that may have been
renamed, showed that almost nothing was:

```bash
find /external-pool/media -type f -printf "%s\t%f\n" > /tmp/ext-files.tsv
awk -F'\t' '
  FNR==NR { have[$2 "\t" $1]=1; if ($1 > 50000000) bysize[$1]=1; next }
  { s=$0; sub(/^ */,"",s); sub(/ .*/,"",s); s+=0
    p=$0; sub(/^ *[0-9]+ [A-Za-z]+, [0-9-]+ [0-9:]+ /,"",p)
    if (s == 0) next
    n=split(p,a,"/"); if ((a[n] "\t" s) in have || s in bysize) next
    printf "%14d\t%s\n", s, p }' /tmp/ext-files.tsv ~/wd10tb-files.txt > ~/wd10tb-missing-files.txt
```

**Files only in older archives.** A repository holds several archives; a
file deleted before the newest one exists only in an older one. Listing
every archive and comparing paths with the newest showed none here (5
archives, 18 to 31 October 2025), so restoring the newest was enough. The
same check, run on the server from step 3, is quick:

```bash
set -a; . /root/borg.env; set +a; repo=${REPO%%::*}
borg list --format "{archive}{NL}" "$repo" > archives.txt
newest=$(tail -1 archives.txt)
borg list --format "{size}\t{path}{NL}" "$repo::$newest" | awk -F'\t' '$1>0' > newest.tsv
while read -r a; do [ "$a" = "$newest" ] && continue
  borg list --format "{size}\t{path}{NL}" "$repo::$a" | awk -F'\t' '$1>0'
done < archives.txt > older.tsv
awk -F'\t' 'NR==FNR {h[$2]; next} !($2 in h) && !($2 in s) {s[$2]; n++} END {print n+0, "files only in older archives"}' newest.tsv older.tsv
```

## 2. Why from far away is slow, and what fixed it

| Tried | Speed |
|---|---|
| `borg mount` on Aurora, copying in Dolphin | ~0.7 MB/s |
| `borg extract` on Aurora | ~0.15 MB/s |
| `borg extract --progress` | nothing for minutes: it first reads the file list of the whole archive to count it |
| Borg on a cloud server in Helsinki, next to the box | 81 MB/s, one process |
| From that server to Aurora, one SSH stream | ~4 MB/s |
| 20 streams side by side, Aurora on its cable | 600 to 770 Mbit/s in total |

Borg fetches the repository's pieces in many small requests, and each one
waits for the round trip: 220 ms between Aurora and Helsinki. Next to the
box that wait is under a millisecond. The second limit is SSH itself: a
single connection keeps only about 2 MB in flight, so across 220 ms it
carries a few MB/s whatever the line can do. More connections side by
side get around that, which is why the speed came from running many
streams.

Mistakes that cost time, worth avoiding next time:

- **Streams through the Mac.** The first rounds went server → Mac → Aurora.
  The Mac was on Wi-Fi, carrying every byte in and out again, which capped
  everything at about 300 Mbit/s. Aurora, on a cable, pulling directly is
  the right shape.
- **One shared SSH connection for all streams** (`ControlMaster`). It saves
  logins but puts every stream on one TCP connection, which brings back the
  single-connection limit, and it refuses new sessions beyond ten. Give
  each stream its own connection.
- **A server too small.** On the smallest type (2 vCPU, 3 GB) about 40 Borg
  processes ran out of memory and the kernel killed them, breaking
  streams. An 8 vCPU / 16 GB type (CPX42) ran 20 streams at about 15 % CPU
  with 12 GB free; 4 vCPU / 8 GB would probably have done too.
- **The server's SSH refused simultaneous logins** beyond its default
  `MaxStartups` (10). Raise it before starting many streams at once.

## 3. The server

A Hetzner Cloud server in the **same location as the storage box**
(Helsinki here), Ubuntu, **IPv6 only** (Aurora and the Mac both have IPv6;
the box and Ubuntu's mirrors answer on it), no private network, volume or
firewall: only your SSH key can log in and it lives for a day or two. Its
included traffic (20 TB) covered the 4.8 TB easily.

Prepare it, and give it a key of its own for the storage box:

```bash
ssh root@<server> 'apt-get update -q && apt-get install -y -q borgbackup && ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/storagebox -C temp-restore && cat ~/.ssh/storagebox.pub'
```

Add that key to the storage box. The box has its own command for it, which
Aurora can run with the backup key:

```bash
echo "<the public key>" | sudo ssh -F /run/agenix/borg-ssh-config borg-wd10tb install-ssh-key
```

The repository's address and passphrase, on the server only. Keep the
passphrase in a file of its own and the other values quoted, so the
settings can be loaded safely in a shell (a first version without quotes
broke on the spaces):

```bash
ssh -t root@<server> 'umask 077; read -rsp "Borg passphrase: " p; echo; printf "%s" "$p" > /root/borg.pass; printf "%s\n" "BORG_PASSCOMMAND=\"cat /root/borg.pass\"" "BORG_RSH=\"ssh -i /root/.ssh/storagebox -o StrictHostKeyChecking=accept-new\"" "REPO=\"ssh://<user>@<user>.your-storagebox.de:23/./backups::<archive>\"" > /root/borg.env'
```

Let it accept many logins at once:

```bash
ssh root@<server> 'echo "MaxStartups 100:30:200" > /etc/ssh/sshd_config.d/restore.conf && sshd -t && systemctl reload ssh'
```

Check it can open the repository, and how fast it reads:

```bash
ssh root@<server> 'set -a; . /root/borg.env; set +a; borg list --last 2 "${REPO%%::*}"'
```

## 4. Lists of paths, one per stream

The work is cut into lists of paths of about equal size: folders, or
single files when a folder is too big. Each list becomes one stream. From
the file list of step 1, with a short script that groups paths, splits any
folder bigger than the target into its children, and fills the lists
largest first:

```python
import collections, re
pre = "run/media/haoji/elexfat/"
rx = re.compile(r"^\s*(\d+) \w+, [\d-]+ [\d:]+ (.*)$")
items = [(int(m[1]), m[2][len(pre):]) for l in open("wd10tb-files.txt")
         if (m := rx.match(l.rstrip("\n"))) and m[2].startswith(pre)]
LISTS = 48
target = sum(s for s, _ in items) / LISTS

def units(prefix, its):
    groups = collections.defaultdict(list)
    for s, rel in its:
        head = (rel[len(prefix) + 1:] if prefix else rel).split("/", 1)[0]
        groups[f"{prefix}/{head}" if prefix else head].append((s, rel))
    out = []
    for u, g in groups.items():
        size = sum(s for s, _ in g)
        if size > target and any(rel != u for _, rel in g):
            out += units(u, [(s, rel) for s, rel in g if rel != u])
        else:
            out.append((size, u))
    return out

bins = [[0, []] for _ in range(LISTS)]
for size, u in sorted(units("", items), reverse=True):
    b = min(bins, key=lambda b: b[0]); b[0] += size; b[1].append(u)
for i, (size, us) in enumerate(bins, 1):
    open(f"lists/{i:02d}.txt", "w").write("".join(pre + u + "\n" for u in us))
```

The lists go to the server (`/root/round3/NN.txt` here), and the order to
run them in to Aurora as `queue.txt`, one list number per line.

## 5. Streaming to Aurora

On Aurora, a key of its own for the server (no passphrase, so streams start
without anyone at the keyboard; authorised on the server with `restrict`),
and the server's host key pinned:

```bash
ssh-keygen -q -t ed25519 -N "" -C aurora-restore -f ~/restore/key
# on the server: echo "restrict $(cat key.pub)" >> /root/.ssh/authorized_keys
```

`~/restore/one.sh`, one list: stream it, unpack it, and mark it done only
if both sides succeeded. Borg's `export-tar` writes a tar of the listed
paths; `--strip-components=4` drops `run/media/haoji/elexfat`, and `-i`
lets tar read several archives in a row (xargs may call Borg more than once
for a long list).

```bash
#!/usr/bin/env bash
n=$1; dir=$HOME/restore
[ -e "$dir/done/$n" ] && exit 0
ssh -i "$dir/key" -o IdentitiesOnly=yes -o UserKnownHostsFile="$dir/known_hosts" \
  -o BatchMode=yes -o ServerAliveInterval=30 root@<server> \
  "set -a; . /root/borg.env; xargs -d '\n' -a /root/round3/$n.txt borg export-tar \"\$REPO\" -" \
  2> "$dir/logs/$n.err" \
  | tar -x -i -C /external-pool/restore-wd10tb --strip-components=4 2>> "$dir/logs/$n.err"
s=("${PIPESTATUS[@]}")
if [ "${s[0]}" = 0 ] && [ "${s[1]}" = 0 ]; then touch "$dir/done/$n"; echo "$(date +%T) list $n done"
else echo "$(date +%T) list $n FAILED (ssh/borg ${s[0]}, tar ${s[1]}); see logs/$n.err"; fi
```

`~/restore/run.sh`, the queue, `<streams>` at a time; running it again
skips finished lists and repeats failed or interrupted ones:

```bash
#!/usr/bin/env bash
P=${1:-20}; dir=$HOME/restore
echo "$(date +%T) $P streams, $(ls "$dir/done" | wc -l) of $(wc -l < "$dir/queue.txt") lists already done"
xargs -P "$P" -I{} bash "$dir/one.sh" {} < "$dir/queue.txt"
echo "$(date +%T) finished: $(ls "$dir/done" | wc -l) of $(wc -l < "$dir/queue.txt") lists done"
```

Started in the background, so it carries on without any SSH session:

```bash
ssh aurora 'mkdir -p ~/restore/logs ~/restore/done && setsid nohup bash ~/restore/run.sh 20 > ~/restore/run.log 2>&1 < /dev/null &'
ssh aurora 'ls ~/restore/done | wc -l; grep -c FAILED ~/restore/run.log; tail -3 ~/restore/run.log'
```

20 streams filled about 85 % of the 740 Mbit/s line; more would only have
taken bandwidth from the rest of the house.

**The last lists slow down.** Near the end, the last three streams fell to
0.3 to 0.5 MB/s each, after five hours on the same connections. The
missing part (20 GB of 260) was cut into 20 new lists of single files and
run as fresh streams, which took minutes. Kill the old list scripts with
`kill -9` before their ssh and tar, so they don't log a failure.

## 6. Being told if it breaks

A temporary service checked the queue every 10 minutes and failed if a
list failed or the runner died early; Aurora's heartbeat reports any failed
service, and Uptime Kuma sends the Telegram message. systemd starts it
without NixOS's program path, which the script has to set itself (the
first version couldn't find `ls` or `grep` and would have missed a
failure):

```bash
#!/usr/bin/env bash
export PATH=/run/current-system/sw/bin
d=/home/haoji/restore
total=$(wc -l < "$d/queue.txt"); done=$(ls "$d/done" | wc -l)
if grep -q FAILED "$d/run.log"; then echo "restore: a list failed"; exit 1; fi
if ! pgrep -f "[r]estore/run.sh" > /dev/null && [ "$done" -lt "$total" ]; then
  echo "restore: the runner stopped with $done of $total lists done"; exit 1
fi
echo "restore: $done of $total lists done, no failures"
```

```bash
ssh -t aurora 'sudo systemd-run --unit=restore-watch --on-calendar="*:0/10" /run/current-system/sw/bin/bash /home/haoji/restore/check.sh'
ssh -t aurora 'sudo systemctl stop restore-watch.timer'    # afterwards
```

## 7. Verifying

Every file of the archive's list compared with the restored folder by
path and exact size; here all 55,519 files, 4,826.4 GB, matched, none
missing, none extra:

```bash
cd /external-pool/restore-wd10tb && find . -type f -printf "%s\t%P\n" > /tmp/ondisk.tsv
awk -F'\t' 'FNR==NR { have[$2]=$1; next }
  { s=$0; sub(/^ */,"",s); sub(/ .*/,"",s); s+=0
    p=$0; sub(/^ *[0-9]+ [A-Za-z]+, [0-9-]+ [0-9:]+ /,"",p); sub(/^run\/media\/haoji\/elexfat\//,"",p)
    if (s == 0) next
    n++; if (!(p in have)) m++; else if (have[p] != s) d++ }
  END { print n, "files:", m+0, "missing,", d+0, "of a different size" }' /tmp/ondisk.tsv ~/wd10tb-files.txt
```

## 8. Cleaning up

1. Stop the watcher.
2. Delete the cloud server (it bills by the hour).
3. Remove its key from the storage box. The box's `authorized_keys` holds
   it twice, as an OpenSSH line and an RFC4716 block, both written by
   `install-ssh-key`. Download the file, remove both, check that the
   backup key is still in it before uploading (or the upload locks Aurora
   out), then check the backup key still logs in:

   ```bash
   sftp -q -F /run/agenix/borg-ssh-config -b - borg-wd10tb <<< "get .ssh/authorized_keys keys.orig"
   # remove the temp-restore line and the SSH2 block whose Comment names it, into keys.new
   grep -q -F "$(ssh-keygen -y -f /run/agenix/borg-ssh-key | cut -d' ' -f2)" keys.new || exit 1
   sftp -q -F /run/agenix/borg-ssh-config -b - borg-wd10tb <<< "put keys.new .ssh/authorized_keys"
   ssh -F /run/agenix/borg-ssh-config borg-wd10tb ls .ssh
   ```

4. Remove Aurora's restore key and scripts.
5. Delete the old repository only once the restored data has an off-site
   backup of its own: until then it is the only second copy.
