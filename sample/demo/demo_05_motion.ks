# 播放bgm语句，<bgm名称>为背景列表中的bgm_name
actor show Kona 正常 at 3
# 改变角色的表情
actor change Kona 介绍说话

"Kona" "konado内置了一些动作"

# addons/konado/template/character/actor_motion_layer.tscn
# 可以自行扩展动作，作用于CharcterMount上即可
"Kona" "内置动作shake"
actor motion Kona shake
"Kona" "内置动作jump"
actor motion Kona jump
"Kona" "内置动作jump_twice"
actor motion Kona jump_twice
"Kona" "内置动作bounce"
actor motion Kona bounce

"Kona" "动作可以自行扩展"
"Kona" "位置：addons/konado/template/character/actor_motion_layer.tscn"

# 演员退出
actor exit Kona

# 结束语句，是关闭对话框的作用
end
