#!/bin/bash

# Where the collectors find omp's sign-ins: its agent tree and agent.db,
# resolved as omp 18 resolves them (@oh-my-pi/pi-utils dirs.ts), and the
# newest enabled literal key in it, with omp's old auth.json as a fallback.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
source "$SHELL_TEST_DIR/agent-usage-helpers.sh"

agent_sandbox

python3 - <<'PY'
import os
import sys
from pathlib import Path

from agent_usage_fixtures import *

sys.path.insert(0, str(Path(os.environ["ROOT"]) / "shell" / "plugins" / "agents"))
import collectors  # noqa: E402

sandbox()
os.environ.pop("XDG_DATA_HOME", None)
expect("omp's agent tree defaults to ~/.omp/agent", collectors.omp_agent_dir(), home() / ".omp" / "agent")
expect("agent.db defaults into the agent tree", collectors.omp_agent_db(), home() / ".omp" / "agent" / "agent.db")

os.environ["PI_CODING_AGENT_DIR"] = "~/moved"
expect("PI_CODING_AGENT_DIR moves omp's tree, a leading ~ expanded", collectors.omp_agent_dir(), home() / "moved")

os.environ["OMP_PROFILE"] = "work"
expect("a named profile ignores PI_CODING_AGENT_DIR", collectors.omp_agent_dir(), home() / ".omp" / "profiles" / "work" / "agent")
os.environ["OMP_PROFILE"] = ""
os.environ["PI_PROFILE"] = "other"
expect("an empty OMP_PROFILE selects the default profile over PI_PROFILE", collectors.omp_agent_dir(), home() / "moved")
del os.environ["OMP_PROFILE"]
expect("PI_PROFILE selects a profile when OMP_PROFILE is unset", collectors.omp_agent_dir(), home() / ".omp" / "profiles" / "other" / "agent")
del os.environ["PI_PROFILE"]
del os.environ["PI_CODING_AGENT_DIR"]

# agent.db is XDG data once `omp config init-xdg` made $XDG_DATA_HOME/omp.
os.environ["XDG_DATA_HOME"] = str(home() / ".local" / "share")
expect("agent.db stays in the tree until omp migrated to XDG", collectors.omp_agent_db(), home() / ".omp" / "agent" / "agent.db")
(home() / ".local" / "share" / "omp").mkdir(parents=True)
expect("agent.db follows omp to $XDG_DATA_HOME/omp", collectors.omp_agent_db(), home() / ".local" / "share" / "omp" / "agent.db")
os.environ["PI_CODING_AGENT_DIR"] = str(home() / "moved")
expect("a moved tree keeps agent.db in it, never XDG", collectors.omp_agent_db(), home() / "moved" / "agent.db")
del os.environ["PI_CODING_AGENT_DIR"]
(home() / ".local" / "share" / "omp").rmdir()

expect("no store, no key", collectors.omp_api_key(("deepseek",)), ("", ""))
pi_auth(home() / ".omp" / "agent", "deepseek", "legacy")
expect("omp's old auth.json is the fallback", collectors.omp_api_key(("deepseek",)), ("legacy", "deepseek"))
omp_key(None, "deepseek", "older")
omp_key(None, "zhipu-coding-plan", "newest-other")
omp_key(None, "deepseek", "newer")
omp_key(None, "deepseek", "disabled", disabled="quota")
omp_key(None, "deepseek", "$DEEPSEEK_KEY")
expect("the newest enabled literal key in agent.db wins over auth.json", collectors.omp_api_key(("deepseek",)), ("newer", "deepseek"))
expect("any of several provider ids, newest first", collectors.omp_api_key(("deepseek", "zhipu-coding-plan")), ("newer", "deepseek"))
expect("only the provider ids asked for", collectors.omp_api_key(("zhipu-coding-plan",)), ("newest-other", "zhipu-coding-plan"))

db = home() / ".omp" / "agent" / "agent.db"
before = db.read_bytes()
collectors.omp_api_key(("deepseek",))
expect("omp's store is never written", db.read_bytes() == before, True)
db.write_text("not a database")
expect("a damaged store falls back to auth.json", collectors.omp_api_key(("deepseek",)), ("legacy", "deepseek"))
PY
