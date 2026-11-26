# 2026-11-26 神经网络学习记录：实际 Day 15——MNIST 选择性数据增强实验

> 归档日期：2026-11-26  
> 学习阶段：实际 Day 15  
> 状态：自定义 Dataset、选择性数据增强、CNN 训练与验证、三组方案对比、类别指标和误分类分析已完成；同一图片的 Logits 对比作为下一步深入分析  
> 数据集：MNIST，训练集 55,000、验证集 5,000、测试集 10,000

## 一、实验目标

Day 14 的混淆矩阵和误分类分析发现，Baseline CNN 在验证集上有真实数字 8 被预测成 9 的错误。此前测试集分析也观察到 8→9 混淆。基于这些现象，提出假设：数字 8 的书写尺寸和形态变化可能影响识别，因此尝试只对训练集中的数字 8 进行适度数据增强（Data Augmentation）。

本阶段重点：
- 理解数据增强的作用，以及训练集、验证集、测试集的数据边界。
- 自定义 Dataset，只对标签为 8 的训练图片进行随机增强。
- 保持验证集和测试集原始分布。
- 训练 CNN 并比较 Baseline、组合增强、仅缩放三种方案。
- 使用 Confusion Matrix、Recall、Precision、F1-Score 分析数字 8 的识别变化。
- 根据误分类样本提出下一轮实验问题。

## 二、代码与数据处理知识

### 1. 图像展示与随机增强预览

本机文件：`mnist_augmentation_preview.py`。

使用 MNIST 找到一张标签为 8 的原始图片，分别生成多张随机增强图片并用 Matplotlib 展示。

涉及知识：
- `datasets.MNIST(..., transform=None)`：先读取原始 PIL 图片，不自动转换。
- `transforms.ToTensor()`：把图片转换为 Tensor，常见 8 位像素值缩放到 [0,1]。
- `transforms.Compose([...])`：按顺序组合多个图像变换。
- `transforms.RandomAffine(degrees=10, translate=(0.08,0.08), scale=(0.95,1.05)))：随机旋转、平移、缩放。
- `[augment(image) for _ in range(5)]`：列表推导式；每次调用都会重新随机采样变换参数，不是简单复制同一张增强图片。
- Matplotlib：`plt.subplots()` 创建 Figure 和 Axes；`imshow()` 显示图片；`set_title()` 设置标题；`axis("off")` 隐藏坐标轴；`tight_layout()` 调整布局；`show()` 显示画布。
- `squeeze()` 删除大小为 1 的维度；`.numpy()` 将 CPU Tensor 转为 NumPy 数组供 Matplotlib 显示。
- `enumerate()` 同时取得循环编号和当前 Axes；`axes.flat` 可遍历二维子图数组。

用户能够解释随机增强多次调用的原因、`squeeze().numpy()` 的作用，并理解 Figure 是整张画布、Axes 是子图区域集合。对 Matplotlib 的全部 API 不要求死记，重点是知道用途和结构。

### 2. 自定义 Dataset：SelectiveAugmentationDataset

本机文件：`mnist_cnn_aug.py`。

用户独立编写了自定义数据集类，核心结构：

- `class SelectiveAugmentationDataset(Dataset)`：继承 PyTorch Dataset。
- `__init__()`：保存原始数据集、增强方法和普通 ToTensor 转换工具。
- `__len__()`：返回原始数据集长度。
- `__getitem__(index)`：根据索引读取图片和标签；若标签为 8 且提供增强方法，则执行增强；否则只执行 ToTensor；最后返回图片和原标签。

重要代码逻辑：

```python
if label == 8 and self.augment_transform is not None:
    image = self.augment_transform(image)
else:
    image = self.to_tensor(image)

return image, label
```

调试中修正了两个问题：
- 初始化时保存属性的名称必须与后续使用一致：统一为 `self.augment_transform`。
- 普通转换必须放在 `else` 分支，否则增强后的图片也会再次走普通转换。

### 3. Dataset 与 DataLoader 检查

数据流程：
- 先用 `random_split(raw_dataset, [55000, 5000])` 划分训练集和验证集。
- 训练子集包装为选择性增强 Dataset，并传入增强变换。
- 验证子集包装为不带增强方法的 Dataset。
- 官方测试集使用 `transform=transforms.ToTensor()`，不做增强。
- 三个 DataLoader 的 batch_size 均为 64；训练集 shuffle=True，验证集和测试集 shuffle=False。

实际检查结果：
- 自定义 Dataset 长度：60,000。
- 数字 8 的单张图片 Tensor 形状：(1,28,28)。
- 其他数字的单张图片 Tensor 形状：(1,28,28)。
- 用 `torch.equal()` 检查：数字 8 的增强结果与原图不同（True）；其他数字经普通 ToTensor 后与原始 ToTensor 结果相同（True）。
- 训练 Batch 图片：(64,1,28,28)，标签：(64,)；示例 Batch 中有 10 张数字 8。
- 验证 Batch 图片：(64,1,28,28)，标签：(64,)。
- 测试 Batch 图片：(64,1,28,28)，标签：(64,)。

关键实验规范：只增强训练集；验证集和测试集保持原始数据分布。数据增强在读取训练样本时在线执行，不需要永久保存所有增强图片。

### 4. CNN 前向传播维度调试

复用 Day 13 CNN：
Conv2d(1,8,3,padding=1) → ReLU → MaxPool2d(2,2) → Flatten → Linear(1568,128) → ReLU → Linear(128,10)。

曾出现报错：
`RuntimeError: mat1 and mat2 shapes cannot be multiplied (8x196 and 1568x128)`。

排查发现：DataLoader 本身返回 (64,1,28,28) 正常，但后续变量被单张图片 (1,28,28) 覆盖，导致传入模型时缺少 Batch 维度。PyTorch Conv2d 可以接受不带 Batch 的三维输入，因此错误直到 Linear 层才显现。

通过使用独立变量 `batch_images`、`batch_labels` 重新取 Batch 并打印形状，确认正确数据流：
- 输入：(64,1,28,28)。
- 卷积后：(64,8,28,28)。
- 池化后：(64,8,14,14)。
- 展平后：(64,1568)。
- 输出：(64,10)。

复习：
- 单张图片：(1,28,28)。
- Batch 图片：(B,1,28,28)。
- `unsqueeze(0)` 可在最前面增加 Batch 维度。
- `squeeze()` 删除大小为 1 的维度；`reshape()` 改变张量形状。
- 不同用途尽量使用不同变量名，避免把单张图片和 Batch 都命名为 `images`。

### 5. 独立训练循环与验证循环

用户根据代码框架独立编写训练与验证流程，修正过以下错误：
- 训练时误写 `torch.no_grad()`，应使用 `optimizer.zero_grad()` 清空梯度。
- 损失函数应比较模型输出和真实标签：`criterion(outputs, batch_labels)`，不是把原始图片传入损失函数。
- 训练循环应统一使用当前 Batch 的标签变量，避免误用之前遗留的 `labels`。
- Loss 累计使用 `loss.item() * batch_size`，最后除以总样本数，正确处理最后一个不完整 Batch。
- 验证时使用 `model.eval()` 和 `torch.no_grad()`，不执行反向传播和优化器更新。

## 三、实验配置

三种方案保持相同的基本 CNN 结构和主要训练配置：
- MNIST：训练集 55,000，验证集 5,000，测试集 10,000。
- Batch Size：64。
- Epoch：3。
- 优化器：Adam。
- 学习率：0.001。
- 损失函数：CrossEntropyLoss。
- CNN：Conv2d(1,8,3,padding=1) → ReLU → MaxPool2d(2,2) → Flatten → Linear(1568,128) → ReLU → Linear(128,10)。
- 选择性增强只应用于训练集的标签 8；验证集保持原始图片。

实验方案：
1. Baseline：不进行数据增强。
2. 组合增强：数字 8 使用 RandomAffine(degrees=10, translate=(0.08,0.08), scale=(0.95,1.05))。
3. 仅缩放：数字 8 使用 RandomAffine(degrees=0, translate=None, scale=(0.95,1.05))。

## 四、训练与验证结果

### 1. Baseline CNN

| Epoch | Train Loss | Train Accuracy | Val Loss | Val Accuracy |
|---:|---:|---:|---:|---:|
| 1 | 0.3313 | 90.43% | 0.1807 | 94.40% |
| 2 | 0.1374 | 95.93% | 0.1236 | 96.02% |
| 3 | 0.0940 | 97.13% | 0.1029 | 96.64% |

验证集真实数字 8 的混淆矩阵行（预测类别 0–9）：

```text
[1, 2, 8, 8, 3, 2, 1, 1, 461, 17]
```

- 验证集中真实数字 8：504 张。
- 正确识别为 8：461 张。
- Recall(8) = 461/504 = 91.47%。
- 被预测为 8 的图片总数：475 张。
- Precision(8) = 461/475 = 97.05%。
- F1(8) = 2×461/(504+475) ≈ 94.18%。
- 8→9：17 次。
- Baseline 验证集 Accuracy：96.64%。

Baseline 的测试集结果来自 Day 13：Test Accuracy 97.21%，Test Loss 约 0.088198。此测试结果不是本次三组验证集对照中的同一指标，不与验证集 Accuracy 混用。

### 2. 组合增强：旋转 + 平移 + 缩放

| Epoch | Train Loss | Train Accuracy | Val Loss | Val Accuracy |
|---:|---:|---:|---:|---:|
| 1 | 0.3399 | 90.22% | 0.1681 | 94.86% |
| 2 | 0.1085 | 96.79% | 0.1357 | 96.02% |
| 3 | 0.0736 | 97.80% | 0.0975 | 97.14% |

真实数字 8 的验证集预测分布（预测类别 0–9）：

```text
[1, 0, 12, 16, 3, 4, 6, 4, 457, 1]
```

- 真实数字 8：504 张。
- 正确识别：457 张。
- Recall(8) = 457/504 ≈ 90.67%。
- 8→9：1 次。
- 该方案的 Precision(8) 当时没有计算，不补造数值。
- Val Accuracy：97.14%。

### 3. 仅缩放（Scaling Only）

变换配置：`degrees=0`、`translate=None`、`scale=(0.95,1.05))。

| Epoch | Train Loss | Train Accuracy | Val Loss | Val Accuracy |
|---:|---:|---:|---:|---:|
| 1 | 0.3133 | 91.00% | 0.1659 | 95.30% |
| 2 | 0.1125 | 96.64% | 0.0973 | 97.12% |
| 3 | 0.0693 | 97.91% | 0.0858 | 97.36% |

真实数字 8 的验证集预测分布（预测类别 0–9）：

```text
[3, 0, 2, 0, 2, 1, 1, 0, 490, 5]
```

- 真实数字 8：504 张。
- 正确识别：490 张。
- Recall(8) = 490/504 ≈ 97.22%。
- 被预测为 8 的图片总数：522 张。
- Precision(8) = 490/522 ≈ 93.87%。
- F1(8) = 2×490/(504+522) ≈ 95.52%。
- 8→9：5 次。
- Val Accuracy：97.36%。

被错误预测为 8 的其他类别数量：
- 真实 0→预测 8：2 次。
- 真实 1→预测 8：3 次。
- 真实 2→预测 8：1 次。
- 真实 3→预测 8：14 次。
- 真实 4→预测 8：1 次。
- 真实 5→预测 8：6 次。
- 真实 6→预测 8：1 次。
- 真实 7→预测 8：1 次。
- 真实 9→预测 8：3 次。
- 合计 False Positive：32 次。

## 五、三种方案对比与当前结论

| 方案 | Val Accuracy | Recall(8) | Precision(8) | F1(8) | 8→9 |
|---|---:|---:|---:|---:|---:|
| Baseline | 96.64% | 91.47% | 97.05% | 94.18% | 17 |
| 组合增强 | 97.14% | 90.67% | 未计算 | 未计算 | 1 |
| 仅缩放 | **97.36%** | **97.22%** | 93.87% | **95.52%** | 5 |

当前观察：
- 仅缩放方案在本次单次训练中取得最高验证准确率 97.36%。
- 数字 8 的 Recall 从 Baseline 的 91.47% 提升到 97.22%，多正确识别 29 张真实数字 8。
- 8→9 从 17 次减少到 5 次。
- 但 Precision 从 97.05% 降至 93.87%，因为有 32 张其他数字被错误预测为 8，其中 3→8 有 14 次、5→8 有 6 次。
- 组合增强将 8→9 降至 1 次，但数字 8 的 Recall 降到 90.67%，说明只看单一错误类别会遗漏其他类别错误的变化。
- 仅缩放目前是三种方案中最值得保留的候选方案，但不能仅凭一次训练就断言缩放必然有效或具有普遍优势。

## 六、误分类样本分析

### 1. 8→9

Day 14 已观察过真实数字 8 被识别成 9 的图片。用户提出下半部分圆环较小或不明显时可能与 9 相似的假设。

### 2. 3→8

在 Baseline 验证集里，真实 3→预测 8 有 1 次；仅缩放方案中增加到 14 次。用户展示了 10 张仅缩放模型的 3→8 图片，观察到这些数字 3 的书写形态有差异：有些笔画粗、弧形明显或上下结构紧密，有些仍较开放。部分图形从视觉上可能与 8 有局部相似性。

当前解释仅为观察假设：对 8 做缩放增强后，模型可能扩大了对数字 8 形态的接受范围，导致部分 3、5 等类别被误判为 8。仅凭误分类图片不能证明具体内部机制，下一步可以比较同一张 3→8 图片在 Baseline 与 Scaling 模型上的 Logits。

## 七、实验方法与科研规范

- 数据增强只用于训练集，验证集和测试集保持原始数据。
- 训练集增强采用在线变换，不必把所有增强图片永久保存。
- 不应认为增强越强越好。过强缩放可能造成图像细节丢失、笔画被裁剪或训练数据分布与真实数据不匹配。
- 训练分布与验证/测试分布不一致更准确地说可能是分布偏移（Distribution Shift），不应直接等同于经典过拟合（Overfitting）。
- 当前三个方案均为单次训练结果。随机初始化、Batch 顺序等随机性仍可能影响结果；若要形成更可靠的结论，需要固定实验条件并使用多个随机种子重复训练。
- 目前仅完成验证集评估；增强模型尚未进行最终测试集评估。测试集保留用于最终独立评估，不用于反复调参。
- 目前未测量 FLOPs、推理延迟、内存占用；验证准确率不能代替完整效率评价。

## 八、已掌握与需要继续巩固

本阶段新接触或强化：
- torchvision.transforms：Compose、ToTensor、RandomAffine、degrees、translate、scale。
- Dataset 子类、自定义 `__init__`、`__len__`、`__getitem__`。
- `self` 对象属性、`is not None`、if/else 条件分支。
- 列表推导式、`enumerate()`、`break`、动态创建 Matplotlib 子图。
- DataLoader 的 Batch 形状和变量命名。
- Precision、Recall、F1-Score 与 False Positive。
- 消融实验（Ablation Study）和控制变量的基本思想。
- 分布偏移（Distribution Shift）与增强强度的关系。

需要继续巩固：
- Precision、Recall、F1 与混淆矩阵行列的对应关系。
- 同一张图片在两个模型上的 Logits 比较。
- 随机种子、重复实验与结果波动。
- 自己组织完整 Dataset、DataLoader、训练和验证流程。
- Tensor 维度追踪，避免单张图片和 Batch 变量混用。

## 九、本机练习文件

以下是本机 VS Code 文件，不代表已经上传到 GitHub：
- `mnist_augmentation_preview.py`：MNIST 数字 8 的随机增强预览。
- `mnist_cnn_aug.py`：自定义选择性增强 Dataset、DataLoader、增强 CNN 训练、验证集混淆矩阵和 Precision/Recall 计算。
- `mnist_cnn.py`：Baseline CNN、验证集混淆矩阵和误分类图片分析。

MNIST 数据仍保存在本机 `data` 目录，本次没有上传数据集或 Python 源文件。

## 十、下一步

下一次先做一项深入分析，而不是立即继续调参：

1. 从验证集中选取同一张真实为 3、被 Scaling 模型预测为 8 的图片。
2. 分别输入 Baseline CNN 和 Scaling CNN。
3. 读取两个模型的 10 类 Logits，比较类别 3 与类别 8 的分数。
4. 观察两模型对同一张图片的判断差异。
5. 再决定是否进行多随机种子重复实验，以及是否保留 Scaling Only 方案。
6. 完成验证阶段分析后，再考虑对增强模型进行一次最终测试集评估。

教学方式继续采用逐步撤除提示：新知识和陌生语法逐行解释；复习内容先给框架和提示，让用户自己补全；遇到困难先提示、再给局部代码，最后才给完整答案。重点从“看懂代码”推进到“独立复现和调试”。
