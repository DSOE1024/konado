# 改变角色的表情
actor show Kona 正常 at 3 [framing=medium]
Kona "景别只调整当前演员，不会移动背景或其他演员"
actor framing Kona close [duration=0.4] [transition=ease_in_out]
Kona "不同演员可以独立使用不同景别"
actor framing Kona default [duration=0.4]
# 改变角色的状态
actor change Kona 介绍说话

Kona "konado内置了一些动作"

# addons/konado/templates/default/character/konado_actor_motion_layer.tscn
# 可以自行扩展动作；动画应作用于 MotionTransform，避免覆盖持久景别
Kona "内置动作shake"
actor motion Kona shake
Kona "内置动作jump"
actor motion Kona jump
Kona "内置动作jump_twice"
actor motion Kona jump_twice
Kona "内置动作bounce"
actor motion Kona bounce

Kona "动作可以自行扩展"
Kona "位置：addons/konado/templates/default/character/konado_actor_motion_layer.tscn"

actor change Kona 害羞
Kona "内置动作演示完毕"
# 演员退出
actor exit Kona

background bg_end fade

# 结束语句，是关闭对话框的作用
end
