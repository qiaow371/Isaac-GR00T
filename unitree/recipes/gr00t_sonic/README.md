# G1 SONIC：本机采集 → 训练 → 仿真/真机推理

官方闭环胶水。代码在 `~/VLA`，**不进本仓**。

| 仓 | 路径 | 干什么 |
|---|---|---|
| [Isaac-GR00T](https://github.com/NVIDIA/Isaac-GR00T)（本机 fork `tongbot`） | `~/VLA/Isaac-GR00T` | 微调 + PolicyServer |
| [GR00T-WholeBodyControl](https://github.com/NVlabs/GR00T-WholeBodyControl) | `~/VLA/GR00T-WholeBodyControl` | PICO 采集、`process_dataset`、`gear_sonic_deploy` |

**不要**用 [`recipes/gr00t/`](../gr00t/)：那是 TongBot 双臂 **16D** / `NEW_EMBODIMENT` / 端口 **5555**。  
这一套是 Unitree G1 / `UNITREE_G1_SONIC` / **5550** / 动作 **64 `motion_token` + 双手 7+7（绝对）**。

VLA 必须跑在本机 GPU（RTX PRO 6000）。G1 机载 Orin NX **不够**同时扛 VLA+WBC。相机服务在 G1（`192.168.123.164`），和 TongBot `192.168.1.x` 不是一张网。

文档：[采集](https://nvlabs.github.io/GR00T-WholeBodyControl/tutorials/data_collection.html) · [微调](https://nvlabs.github.io/GR00T-WholeBodyControl/tutorials/vla_workflow.html) · [推理](https://nvlabs.github.io/GR00T-WholeBodyControl/tutorials/vla_inference.html)

---

## 一次过

```bash
cd /path/to/data_Driven

bash recipes/gr00t_sonic/setup.sh
# 仿真依赖 / 采集 venv / 推理 venv / SONIC 权重，按需：
# bash recipes/gr00t_sonic/setup.sh --install-sim --install-collect --install-infer --download-sonic
# PICO 真机遥操再加 --install-pico

bash recipes/gr00t_sonic/check.sh

# 1) 采（仿真先跑通；真机要 PICO 4/4 Pro + 踝 tracker + G1 相机）
bash recipes/gr00t_sonic/collect.sh --sim --prompt "pick up the cookie box"
bash recipes/gr00t_sonic/collect.sh --real --prompt "pick up the cookie box"

# 2) 清洗。VR_3PT（SMPL 全 0）必须加 --no-remove-stale-smpl
bash recipes/gr00t_sonic/process.sh \
  --dataset-path /path/to/raw_session \
  --output-path /path/to/cleaned

# 3) 训（焊死 UNITREE_G1_SONIC；本机默认 1 卡 batch 32、20k step）
bash recipes/gr00t_sonic/train.sh --dataset-path /path/to/cleaned

# 4) 推理：先 PolicyServer，再 SONIC。仿真/真机同一套 ckpt + 同一套 SONIC 权重。
bash recipes/gr00t_sonic/server.sh ~/VLA/gr00t_sonic_outputs/g1_sonic_cookiebox/checkpoint-20000
bash recipes/gr00t_sonic/infer.sh --sim --prompt "pick up the cookie box"
bash recipes/gr00t_sonic/infer.sh --real --prompt "pick up the cookie box"
```

`SONIC_VARIANT` 默认 **`v1.1`**（官方给「对着这套控制器训的 VLA」）。采集和上机必须同一套：

```bash
export SONIC_VARIANT=v1.1          # 或 default / low_latency
```

v1.1 会带踝 pitch `4,10=1.5`。换 decoder = 换 latent，cookiebox 若是 default 采的，不要用 v1.1 去解。

---

## 仿真 vs 真机

| | 仿真 `--sim` | 真机 `--real` |
|---|---|---|
| 采集 | `launch_data_collection.py --sim`（MuJoCo 自己推图，不要相机服务） | PICO + `gear_sonic_deploy real` + G1 相机 `192.168.123.164:5555` |
| 推理 | `launch_inference.py --sim` | 同上，PolicyServer 可在本机 `127.0.0.1:5550` |
| C++ | `./deploy.sh … sim` | `./deploy.sh … real`（x86 TensorRT **10.13**；Orin 上编要 **10.7** + JetPack 6） |

真机键盘：`k` 开环 → `i` 混到初始 pose → `p` 开 VLA。初始 64 维 token 在 `gear_sonic/utils/inference/initial_poses.py`，应对齐演示第 0 帧的 `action.motion_token`。

---

## 硬约束

- embodiment **只能** `UNITREE_G1_SONIC`。`UNITREE_G1` 是 decoupled WBC，和 cookiebox 对不上。
- 动作是 **绝对** FSQ token，不要 `use_relative_action`。
- 训练相机 config 只吃 **`ego_view`**。
- VLA **2.5 Hz** / chunk **40**；SONIC **50 Hz**。
- 不要和 TongBot `recipes/gr00t/start_gr00t_server.sh` 同时占混乱端口语义。
- H100 只适合训练；真机 PolicyServer 放本机 GPU，远程机房延迟会把 40 步 chunk 吃掉。

已有 cookiebox（H100 `real_g1_demo_pick_cookiebox_4he_l`）已经是这套 LeRobot 格式，可直接 `--dataset-path` 微调，不必改成关节 `q`。

---

## 公开数据集（能当 SONIC 训的）

NVIDIA **没有**放 benchmark 里那 18k 桌面抓取 / 150 汽水罐 VLA 演示。GitHub 上也没有 cookiebox。

| 集 | 行不行 | 说明 |
|---|---|---|
| [SII-ZhangYiFei/G1-WholeBody-PickPlaceToy](https://huggingface.co/datasets/SII-ZhangYiFei/G1-WholeBody-PickPlaceToy) | **可以** | 128 ep / 50 Hz / `motion_token` 64。任务：玩具放到椅子。仿真物体用 `--sim-scene pickplace` |
| [wsagi/SONIC-VLA-BonesSeed](https://huggingface.co/datasets/wsagi/SONIC-VLA-BonesSeed) | 只能冒烟 | 7 条走/跳/舞，空场地 |
| [nvidia/PhysicalAI-Robotics-GR00T-Teleop-G1](https://huggingface.co/datasets/nvidia/PhysicalAI-Robotics-GR00T-Teleop-G1) | **不行** | 43 维关节，不是 token，不能喂 `UNITREE_G1_SONIC` |
| `nvidia/GEAR-SONIC` `--training` | 不是 VLA | SONIC **控制器**权重 + SMPL |

```bash
bash recipes/gr00t_sonic/download_public_dataset.sh pickplace_toy
bash recipes/gr00t_sonic/install_sim_assets.sh
bash recipes/gr00t_sonic/train.sh \
  --dataset-path ~/VLA/datasets/G1-WholeBody-PickPlaceToy \
  --experiment-name g1_sonic_pickplace_toy
# 训完：
bash recipes/gr00t_sonic/server.sh ~/VLA/gr00t_sonic_outputs/g1_sonic_pickplace_toy/checkpoint-20000
bash recipes/gr00t_sonic/infer.sh --sim --sim-scene pickplace \
  --prompt "pick up the toy and place it on the chair"
```
