# 实际 Day 14：CNN 模型分析与误分类样本

> 日期：2026-11-16  
> 状态：进行中  
> 项目：MNIST CNN（延续实际 Day 13）

## 一、已有 CNN 基线结果

模型结构：

`Conv2d(1,8,3,padding=1) → ReLU → MaxPool2d(2,2) → Flatten → Linear(1568,128) → ReLU → Linear(128,10)`

训练配置：MNIST，训练/验证/测试集 55,000/5,000/10,000；Batch Size=64；Adam；学习率 0.001；训练 3 Epoch。

| Epoch | Train Loss | Train Accuracy | Val Loss | Val Accuracy |
|---:|---:|---:|---:|---:|
| 1 | 0.3313 | 90.43% | 0.1807 | 94.40% |
| 2 | 0.1374 | 95.93% | 0.1236 | 96.02% |
| 3 | 0.0940 | 97.13% | 0.1029 | 96.64% |

Test Loss：约 0.088198；Test Accuracy：97.21%。

## 二、误分类样本可视化

在评估阶段使用 `model.eval()` 和 `torch.no_grad()`，遍历 `test_loader`：

1. `outputs = model(images)` 得到模型输出。
2. `predicted = outputs.argmax(dim=1)` 取得每张图片预测类别。
3. 比较 `predicted[i]` 与 `labels[i]`，判断是否预测错误。
4. 最多收集 10 张错误图片，同时保存真实标签和预测标签。
5. 使用 Matplotlib 的 2×5 子图展示图片，并在标题中显示 Pred 与 True。

### 调试记录

最初错误地写成：

```python
wrong_images.append([i])
```

这会把索引 `i` 包装成 Python 列表存进去，而不是保存图片 Tensor。随后绘图时调用：

```python
wrong_images[i].squeeze()
```

因此出现：

`AttributeError: 'list' object has no attribute 'squeeze'`

修正为：

```python
wrong_images.append(images[i].cpu())
```

现在保存的是图片 Tensor，`.squeeze()` 可以去掉大小为 1 的通道维度，交给 `imshow()` 显示。

运行时检查：

- images：`torch.Size([16, 1, 28, 28])`
- labels：`torch.Size([16])`
- predicted：`torch.Size([16])`
- 找到并成功展示 10 张误分类样本。

此前还出现过索引越界错误；本次检查确认当前批次图片、标签和预测数量一致，均为 16。

## 三、概念复习与实验思考

### 误分类分析（Error Analysis）

不只看准确率，还要查看具体错在哪里：哪些数字容易混淆、图片笔画是否模糊、不同手写方式是否影响模型判断。当前已完成 10 张错误图片的可视化和初步观察，尚未统计完整混淆矩阵或各类别错误率。

### 过拟合（Overfitting）判断

讨论情境：Train Accuracy=99.5%，Val Accuracy=95.8%。训练集表现明显好于验证集，应警惕过拟合。

本次问答中，用户能正确判断上述情境为过拟合；对于“准确率 97.21% 后如何改进”的选择题，用户最初选择直接增加 Epoch。复盘结论：增加训练轮数可能有效，但不能只看训练准确率；应先分析错误样本，并用验证集判断是否真正改善泛化能力。

## 四、尚未完成

- 计算并比较 MLP 与 CNN 的可训练参数量。
- 理解卷积层与全连接层参数量计算方式。
- 设计 Epoch 对比实验，记录 Train/Validation Loss 与 Accuracy。
- 观察是否出现训练集继续改善、验证集不再改善或变差的过拟合迹象。
- 可选：统计混淆矩阵和各类别错误数量。

注意：测试集只用于最终评估，不用于选择 Epoch 或调参。

## 五、下一次学习入口

先完成 MLP/CNN 参数量计算，再做控制变量的 Epoch 实验。Day 14 完成后再进入 RNN 序列数据学习。

## 六、本次涉及的本机文件

- `mnist_cnn.py`：CNN 训练、测试评估、特征图与误分类样本可视化（本机文件；未确认已上传仓库）。
- MNIST 数据集保留在本机数据目录，未上传仓库。
