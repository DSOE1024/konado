play bgm echo
background bg_para none
actor show Kona 正常 at 3
"Kona" "你好！欢迎来到我们的咖啡馆。" voice_01
cam move cam2 linear 1.0
achievement unlock "first_blood"
achievement increment "explorer" 1
achievement set_flag "secret_ending_found" true
actor move Kona 1
actor change Kona 介绍说话
"Kona" "和我一起用Konado做视觉小说吧！"
cam move cam1 linear 1.0
actor exit Kona
cam reset linear 1.0
jump res://sample/demo/demo_02.ks
end
