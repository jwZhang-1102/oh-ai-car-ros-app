#! /bin/bash
###############################################################################
# Yahboom run 实际脚本（alias run='.../start_app.sh'）
# 同时启动:
#   app.py  → TCP 6000 + 视频 6500
#   app2.py → 巡检 HTTP 6700（不占摄像头）
#
# 部署到小车（先备份原文件）:
#   cp -a ~/Rosmaster-App/rosmaster/start_app.sh ~/Rosmaster-App/rosmaster/start_app.sh.bak
#   scp 本文件 + app2.py + patrol_server.py → ~/Rosmaster-App/rosmaster/
#   sed -i 's/\r$//' start_app.sh && chmod +x start_app.sh
###############################################################################

sleep 8
cd ~/Rosmaster-App/rosmaster/

# 6000 / 6500（原厂）
gnome-terminal -- bash -c "python3 ~/Rosmaster-App/rosmaster/app.py;exec bash"

# 6700（智检哨兵 HTTP，后台跑即可；无桌面时也可用）
if [ -f ~/Rosmaster-App/rosmaster/app2.py ]; then
  nohup python3 ~/Rosmaster-App/rosmaster/app2.py >> ~/Rosmaster-App/rosmaster/patrol_server.log 2>&1 &
  echo "[start_app] app2.py (6700) started, log: patrol_server.log"
else
  echo "[start_app] WARN: 缺少 app2.py，未启动 6700"
fi

wait
exit 0
