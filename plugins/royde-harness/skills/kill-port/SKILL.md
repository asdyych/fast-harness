---
name: kill-port
description: "Kill process occupying a specific port. Use when a port is in use and needs to be freed. Triggers on: kill port, close port, free port, stop port, port in use, release port."
---

# Kill Port

Terminate the process occupying a specific network port on Windows, **including all child processes**.

---

## The Job

1. Identify the process using the specified port
2. Display process information (name, PID)
3. Find and display child processes
4. Terminate the entire process tree
5. Verify the port is released

---

## Usage

User provides a port number, e.g., "kill port 3000" or "close port 8080"

---

## Steps

### Step 1: Find Process Using Port

```bash
netstat -ano | findstr :<PORT>
```

Look for the `LISTENING` state - the last column is the PID.

### Step 2: Identify Process Name and Check for Children

```bash
wmic process where processid=<PID> get name,processid
```

**CRITICAL: Check for child processes:**
```bash
wmic process where "ParentProcessId=<PID>" get ProcessId,Name
```

Or use PowerShell:
```powershell
Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq <PID> } | Select-Object ProcessId, Name
```

### Step 3: Terminate ENTIRE Process Tree

**ALWAYS use /T flag to kill process tree:**
```bash
taskkill /F /T /PID <PID>
```

- `/F` - Force termination
- `/T` - **Terminate child processes** (CRITICAL for Node.js, Python, etc.)
- `/PID` - Specify process ID

**Do NOT use:**
```bash
taskkill /F /PID <PID>  # BAD: leaves child processes running!
```

### Step 4: Verify Port Released

```bash
netstat -ano | findstr :<PORT>
```

- `LISTENING` should no longer appear
- `TIME_WAIT` states are normal and will clear automatically (30-120 seconds)

**If port still shows LISTENING:** Child processes may have survived. Repeat Step 1-3.

---

## Common Scenarios

| Port | Typical Process | Notes |
|------|-----------------|-------|
| 3000 | Node.js dev server | Often spawns child processes |
| 3104 | Backend API | May have worker children |
| 5173 | Vite dev server | HMR subprocess |
| 8029 | Python backend | Multiprocessing workers |
| 8042 | Multi-agent system | Complex process tree |
| 8080 | Various web servers | - |
| 5432 | PostgreSQL | Service-managed |
| 3306 | MySQL | Service-managed |

---

## Troubleshooting

### Access Denied
Run terminal as Administrator.

### Process Restarts Immediately
The process may be managed by a service. Stop the service instead:
```bash
net stop <service_name>
```

### Port Still Shows LISTENING After Kill
**Child processes survived.** This is common with:
- Node.js (spawns workers)
- Python multiprocessing
- uvicorn/gunicorn workers

Solution:
1. Find surviving processes: `netstat -ano | findstr :<PORT>`
2. Check their parent: `wmic process where processid=<NEW_PID> get ParentProcessId`
3. Kill with tree: `taskkill /F /T /PID <NEW_PID>`

### Port Still Shows TIME_WAIT
This is normal TCP behavior. The port will be available shortly (typically 30-120 seconds). This is NOT an error.

---

## Example Output

```
Port 8042 is being used by:
  Process: python.exe
  PID: 15284

Child processes found:
  PID 15420: python.exe (worker)
  PID 15436: python.exe (worker)

Terminating process tree...
> taskkill /F /T /PID 15284
SUCCESS: The process with PID 15284 (child processes of PID 15284) has been terminated.

Verifying...
> netstat -ano | findstr :8042
[No LISTENING state found]

Port 8042 is now available.
```
