@echo off
chcp 65001 >nul
REM 仅上传 start_patrol_host.sh --bg 必需文件（瓶子+蜂鸣+语音+暂停n3）
REM 用法: deploy_mission_to_car.bat
REM 可选: deploy_mission_to_car.bat 10.147.13.194 jetson
REM 不上传: mission_waypoints.json / start_mission_nav.sh / MISSION.md

set CAR_IP=10.147.13.194
set CAR_USER=jetson
if not "%~1"=="" set CAR_IP=%~1
if not "%~2"=="" set CAR_USER=%~2

cd /d D:\carapp\oh-ai-car-ros-app
if errorlevel 1 (
    echo 错误: 找不到 D:\carapp\oh-ai-car-ros-app
    pause
    exit /b 1
)

echo ========================================
echo  上传到 %CAR_USER%@%CAR_IP%
echo  模式: --bg 瓶子巡检 + 蜂鸣 + 语音 + 暂停n3
echo ========================================

scp jetson/patrol/alert_voice.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/patrol_detector.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/patrol_server.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/nav_mission_coordinator.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/pose_reader.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/rosmaster_buzzer.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/start_patrol_host.sh %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/stop_patrol_host.sh %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/

if errorlevel 1 (
    echo.
    echo 上传失败，请检查 IP、ssh、密码
    pause
    exit /b 1
)

echo.
echo 修复脚本换行并重启巡检...
ssh %CAR_USER%@%CAR_IP% "cd ~/Rosmaster-App/rosmaster && sed -i 's/\r$//' *.sh && chmod +x start_patrol_host.sh stop_patrol_host.sh && bash stop_patrol_host.sh 2>/dev/null; bash start_patrol_host.sh --bg"

echo.
echo ========================================
echo  上传完成（8 个文件），巡检已后台重启
echo  恢复导航: curl -X POST http://127.0.0.1:6700/mission/resume
echo ========================================
pause
