---
title: 外部シグナルを待つ
order: 6
---

# 外部シグナルを待つ

```text
waitsignal "minigame_done"
```

```gdscript
$KND_DialogueManager.emit_wait_signal("minigame_done")
```

同名のシグナルが外部コードから送られるまでシナリオを停止します。
