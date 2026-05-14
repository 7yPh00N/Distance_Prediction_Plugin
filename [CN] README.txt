安装步骤：
1. 将ZIP压缩包中的cstrike文件夹解压至游戏根目录（通常是\Half-Life\）
2. 用记事本打开游戏根目录下的\cstrike\addons\amxmodx\configs\plugins.ini文件
3. 在文件末尾添加一行distance_prediction.amxx
4. 保存该文件并重启游戏

插件指令:
/dps - 打开主菜单
/dp & /distpred - 开启/关闭插件
/sonar - 开启/关闭声呐
/rtpredhud - 开启/关闭实时预测HUD
/bestpredhud - 开启/关闭最佳预测距离统计HUD
/landingpred - 开启/关闭着陆区域可视化/上板预测
/ljpred - Long Jump
/hjpred - High Jump
/cjpred - Count Jump
/scjpred - Stand-Up Count Jump
/dcjpred - Double Count Jump
/wjpred - Weird Jump
/sbjpred - Stand-Up Bhop Jump
/bjpred - Bhop Jump
/ldjpred - Ladder Jump

配置文件:
\cstrike\addons\amxmodx\configs\
 - movementhud_server.ini
 - distance_prediction.ini
 - distance_prediction_thresholds.ini

更新日志：
[V1.5.0] 2026.05.14
1. 改进DHUD
 - 修复延迟1帧闪烁的BUG
 - 将闪烁持续时间由3帧改为5帧（dhud_flashtime 5）
 - 移除DHUD单帧持续时间调整功能
2. 将distance_prediction_server.ini重命名为movementhud_server.ini

[V1.4.0] 2026.04.25
1. 改进跳跃距离预测功能
 - 引入垂直速度与重力加速度以提升计算精确度
2. 新增公共服务器模式（movementhud_server 2）
 - 新增观察者模式
 - 新增中文菜单（menu_language 2）
 - 新增HUD通道自定义功能（hud_best_channel 4）
 - 改进声呐功能以适配公共服务器
3. 新增LDJ跳跃类型（梯子跳）
4. 修复部分溢出BUG

[V1.3.0] 2026.04.15
1. 新增声呐功能
2. 新增13条插件指令
3. 重构Config文件读取/写入方法

[V1.2.0] 2026.04.05
1. 改进着陆区域可视化/上板预测功能
 - 新增开关（ON/OFF）
 - 新增颜色选择功能
 - 修复部分BUG
2. 改进实时显示功能（距离预测）
 - 新增持续时间调整功能

[V1.1.5_beta] 2026.03.31
1. 新增着陆区域可视化/上板预测功能

[V1.1.0] 2026.03.28
1. 新增插件设置菜单（/dps）
2. 新增插件开关（ON/OFF）
3. 新增SBJ、BJ跳跃类型
4. 新增HUD颜色选择功能
5. 新增HUD位置调整功能

[V1.0.5_beta] 2026.03.24
1. 新增最佳预测距离统计功能（取各加速区间内的最高值）
2. 改进起跳帧判定逻辑

[V1.0.0] 2026.03.15
1. 新增LJ/HJ/WJ/CJ/DCJ/SCJ跳跃距离预测功能
 - 新增实时显示功能