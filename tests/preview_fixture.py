"""Loopback-only synthetic UI fixture. In-memory state; no real SQLite or cloud access."""
from pathlib import Path
import sys
import threading
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from academy import Store,make_server
store=Store()
server=make_server(store,0)
print(server.server_port,flush=True)
threading.Thread(target=lambda: (sys.stdin.buffer.read(),server.shutdown()),daemon=True).start()
try: server.serve_forever()
finally: server.server_close();store.db.close()
