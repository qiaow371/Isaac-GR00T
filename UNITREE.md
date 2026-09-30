# Unitree G1 SONIC

这一份是 G1 的采集、微调和真机推理。embodiment 是 `UNITREE_G1_SONIC`。动作是 64 维 `motion_token` 加左右手各 7 维，端口 **5550**。不要和 TongBot 双臂的 `recipes/gr00t`（16 维、端口 5555）混用。

| 阶段 | 代码 | 在哪跑 |
|---|---|---|
| 采集、清洗、C++ 全身控制 | `third_party/GR00T-WholeBodyControl`（上游 [NVlabs/GR00T-WholeBodyControl](https://github.com/NVlabs/GR00T-WholeBodyControl)） | 推理机 `infer-zsj` |
| 微调、PolicyServer | 本仓库 | H100 训练；推理机 4090 起服务 |

推理机上的现场树：

- `/home/zsj/workspace/yvshu/Isaac-GR00T`
- `/home/zsj/workspace/yvshu/GR00T-WholeBodyControl`

权重和数据集不进这个仓库。

## 取出代码

```bash
git clone -b unitree-g1-sonic git@github.com:qiaow371/Isaac-GR00T.git
cd Isaac-GR00T
git submodule update --init third_party/GR00T-WholeBodyControl
```

启动脚本在 `unitree/recipes/gr00t_sonic/`。

## 采集和训练

```bash
bash unitree/recipes/gr00t_sonic/setup.sh
bash unitree/recipes/gr00t_sonic/collect.sh --real --prompt "Pick up the cookie box using your right hand ."
bash unitree/recipes/gr00t_sonic/process.sh --dataset-path /path/to/raw --output-path /path/to/cleaned
bash unitree/recipes/gr00t_sonic/train.sh --dataset-path /path/to/cleaned
```

`g1_pick_6_box_2he` 只有这一句任务，推理 prompt 必须和它一致，句号前面有一个空格：

```text
Pick up the cookie box using your right hand .
```

`SONIC_VARIANT` 默认 `v1.1`。采集和解码必须是同一套。

## 推理机上起服务和客户端

在 `zsj@10.151.43.136` 上。U 盘插上后先看挂载名（多半是 `/media/zsj/T9_3` 或 `T9_4`），`--model-path` 指到含 `config.json` 的那一层。

终端 1，策略服务：

```bash
cd /home/zsj/workspace/yvshu/Isaac-GR00T
/home/zsj/workspace/yvshu/Isaac-GR00T/.conda/bin/python gr00t/eval/run_gr00t_server.py \
  --model-path /media/zsj/T9_3/checkpoint/box6_no_turn_l_lr6e5/checkpoint-40000 \
  --embodiment-tag UNITREE_G1_SONIC \
  --device cuda:0 \
  --host 0.0.0.0 \
  --port 5550
```

终端 2，全身控制。它会开 tmux `sonic_inference`。

```bash
cd /home/zsj/workspace/yvshu/GR00T-WholeBodyControl
python gear_sonic/scripts/launch_inference.py \
  --policy-host 127.0.0.1 \
  --policy-port 5550 \
  --prompt "Pick up the cookie box using your right hand ." \
  --camera-host 192.168.123.164 \
  --camera-port 5555 \
  --deploy-checkpoint policy/sonic_v1_1/model \
  --deploy-obs-config policy/sonic_v1_1/observation_config.yaml \
  --deploy-motor-kp-scale 4,10=1.5 \
  --deploy-motor-kd-scale 4,10=1.5
```

左上 C++ 窗按回车确认。键盘窗：`k` 开控制环，`i` 到初始姿态，`p` 取消暂停。

没有三指时，现成客户端仍会把左右手各 7 维打进 ZMQ。机身只吃 64 维 token。
