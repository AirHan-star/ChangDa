# 松岭余讯

一个用 Godot 4 和 GDScript 制作的第三人称 3D 离线生存原型。你从废弃气象站出发，到林地搜集补给，再把物资送回站内。

## 在 Windows x64 试玩

下载并解压 [Windows 应用包](dist/PineRidgeRelay-Windows-x86_64.zip)，双击 `PineRidgeRelay.exe`。游戏资源已嵌入 EXE，可离线运行，无需安装 Godot。

- 用 **WASD** 移动，鼠标转动镜头，按住 **Shift** 奔跑。
- 按 **Esc** 释放鼠标，左键单击画面继续。
- 沿林间小路寻找金色木料和青色罐头，靠近后按 **E** 拾取。
- 收集 **3 份木料和 1 个罐头**，回到有橙色屋檐的气象站，在站内补给箱旁按 **E** 存入物资。任务完成后会显示“补给任务完成”。

## 在 Godot 中修改和导出

用 Godot **4.6.3** 导入本目录的 `project.godot`，按 **F5** 运行。主场景是 `scenes/main.tscn`。拾取、随身数量、入箱数量和完成条件由 `scripts/supply_rules.gd` 管理。

更新时在本目录修改工程。安装对应版本的 Godot 导出模板后，在编辑器中使用 **Windows Desktop** 预设导出。预设会生成包含游戏资源的 `dist/PineRidgeRelay.exe`。将新 EXE 与现有压缩包内的许可证文件一起打包，替换本目录 `dist/` 下的应用包。
