@echo off
chcp 65001 >nul
REM 一键上传巡检+停车（n3 SIGSTOP 暂停）相关文件到小车
REM 用法: deploy_mission_to_car.bat
REM 可选: deploy_mission_to_car.bat 10.147.13.194 jetson

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
echo  停车策略: 告警 + SIGSTOP 暂停 n3
echo ========================================

scp jetson/patrol/nav_mission_coordinator.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/pose_reader.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/rosmaster_buzzer.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/mission_waypoints.json %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/patrol_server.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
scp jetson/patrol/patrol_detector.py %CAR_USER%@%CAR_IP%:~/Rosmaster-App/rosmaster/
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
echo  上传完成，巡检已后台重启
echo  恢复导航: curl -X POST http://127.0.0.1:6700/mission/resume
echo ========================================
pause
