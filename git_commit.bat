@echo off
cd /d C:\dev\freelance_hub
D:\Git\cmd\git.exe add -A
D:\Git\cmd\git.exe commit -m "docs: update handover - MongoDB replicaSet fix + git init milestone" -m "Fix Atlas connection by correcting replicaSet name (atlas-7jqenn-shard-0). Document diagnostic chain and successful git push."
echo GIT_OP_EXIT=%ERRORLEVEL%