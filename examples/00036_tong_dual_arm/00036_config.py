# 00036 数据集 (tong_dual_arm) 的 GR00T N1.7 模态配置
# 双臂机器人: 左臂7关节 + 右臂7关节 + 左右夹爪 (16D)
# 3 相机: left, front, right（与 00036 v2.1 数据集 video key 一致）
#
# 训练 Prompt:
#   "With both hands, pick up the yellow banana and the yellow lemon
#    and put them into the black box; then take the green vegetables
#    and place them into the blue box."

from gr00t.configs.data.embodiment_configs import register_modality_config
from gr00t.data.embodiment_tags import EmbodimentTag
from gr00t.data.types import (
    ActionConfig,
    ActionFormat,
    ActionRepresentation,
    ActionType,
    ModalityConfig,
)


tong_dual_arm_config = {
    # Video: 3 cameras (current frame)
    "video": ModalityConfig(
        delta_indices=[0],
        modality_keys=[
            "observation.images.left",
            "observation.images.front",
            "observation.images.right",
        ],
    ),
    # State: current joint positions + grippers (16 dims)
    "state": ModalityConfig(
        delta_indices=[0],
        modality_keys=["observation.state"],
    ),
    # Action: 16-step prediction horizon
    "action": ModalityConfig(
        delta_indices=list(range(0, 16)),
        modality_keys=["observation.state"],
        action_configs=[
            # joint space relative actions for better generalization
            ActionConfig(
                rep=ActionRepresentation.RELATIVE,
                type=ActionType.NON_EEF,
                format=ActionFormat.DEFAULT,
            ),
        ],
    ),
    # Language: task instruction
    "language": ModalityConfig(
        delta_indices=[0],
        modality_keys=["annotation.human.task_description"],
    ),
}

register_modality_config(
    tong_dual_arm_config,
    embodiment_tag=EmbodimentTag.NEW_EMBODIMENT,
)
