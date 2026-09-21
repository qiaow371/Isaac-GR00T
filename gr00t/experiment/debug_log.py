"""Train debug log helpers for GR00T N1.7 (unreduced action FM-MSE).

See data_Driven docs/TRAIN_DEBUG_LOG.md. TongBot dual-arm is 16D joints,
padded to max_action_dim; pad dims are zeroed by action_mask.
"""

from __future__ import annotations

from typing import Dict, Optional

import torch

JOINT_16 = [f"L{j}" for j in range(1, 8)] + [f"R{j}" for j in range(1, 8)] + ["Lgrip", "Rgrip"]


def dim_names(d: int) -> list[str]:
    names = list(JOINT_16)
    if d > 16:
        names.extend(f"pad{i}" for i in range(d - 16))
    return names[:d]


def _masked_mean(loss: torch.Tensor, valid: torch.Tensor, dims: tuple[int, ...]) -> torch.Tensor:
    num = (loss * valid).sum(dim=dims)
    den = valid.sum(dim=dims).clamp(min=1.0)
    return num / den


def action_debug_stats(
    action_loss: torch.Tensor,
    action_mask: Optional[torch.Tensor] = None,
) -> Dict[str, float]:
    """Slice unreduced action MSE [B, T, D] into cheap python floats."""
    loss = action_loss.detach().float()
    if action_mask is None:
        valid = torch.ones_like(loss)
    else:
        valid = action_mask.detach().float()
        if valid.shape != loss.shape:
            valid = valid.expand_as(loss)

    b, t, d = loss.shape
    names = dim_names(d)
    per_dim = _masked_mean(loss, valid, (0, 1))
    per_step = _masked_mean(loss, valid, (0, 2))
    stats: Dict[str, float] = {}

    for i, name in enumerate(names):
        stats[f"Action loss dim/{name}"] = float(per_dim[i].item())
    if t > 0:
        stats["Action loss per_step/head"] = float(per_step[0].item())
        stats["Action loss per_step/tail"] = float(per_step[-1].item())
        stats["Action loss per_step/tail_head_ratio"] = float(
            (per_step[-1] / per_step[0].clamp(min=1e-8)).item()
        )
        for i in range(t):
            stats[f"Action loss per_step/{i}"] = float(per_step[i].item())

    real = min(d, 16)
    if real >= 16:
        stats["Action loss group/L_joints"] = float(per_dim[0:7].mean().item())
        stats["Action loss group/R_joints"] = float(per_dim[7:14].mean().item())
        stats["Action loss group/grip"] = float(per_dim[14:16].mean().item())
    if d > 16:
        pad_valid = valid[:, :, 16:].reshape(-1)
        pad_loss = loss[:, :, 16:].reshape(-1)
        if float(pad_valid.sum().item()) > 0:
            stats["training/pad_mean"] = float((pad_loss * pad_valid).sum().item() / pad_valid.sum().clamp(min=1).item())
        else:
            stats["training/pad_mean"] = float(per_dim[16:].mean().item())
        stats["Action loss group/pad"] = stats["training/pad_mean"]

    finite = torch.isfinite(loss)
    stats["training/nan"] = float((~finite).float().mean().item())
    stats["training/action_loss"] = float(_masked_mean(loss, valid, (0, 1, 2)).item())
    return stats
