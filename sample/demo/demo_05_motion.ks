# 改变角色的表情
actor show Kona 正常 at 3
# 改变角色的状态
actor change Kona 介绍说话

"Kona" "konado内置了一些动作"

"Kona" "内置动作shake"
actor motion Kona shake
"Kona" "内置动作shake"
actor motion Kona jump
"Kona" "内置动作jump_twice"
actor motion Kona jump_twice
"Kona" "内置动作bounce"
actor motion Kona bounce

actor change Kona 害羞
"Kona" "内置动作演示完毕"
# 演员退出
actor exit Kona

background bg_end fade

# 结束语句，是关闭对话框的作用
end
