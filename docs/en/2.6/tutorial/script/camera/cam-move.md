---
title: Move camera
order: 1
---

# Move camera

Move to a uniquely named `KonadoCamera2D` in the current background:

```text
cam move <camera_id> [none|linear|ease_in_out] [seconds]
```

Omitting the transition, or using `none`, moves immediately. An animated transition defaults to one second.
