play bgm echo
background bg_para none
actor show Kona 正常 at 3
"Kona" "안녕하세요! 저희 카페에 오신 것을 환영합니다." voice_01
cam move cam2 linear 1.0
achievement unlock "first_blood"
achievement increment "explorer" 1
achievement set_flag "secret_ending_found" true
actor move Kona 1
actor change Kona 介绍说话
"Kona" "Konado로 함께 비주얼 노벨을 만들어 봐요!"
cam move cam1 linear 1.0
actor exit Kona
cam reset linear 1.0
jump res://sample/demo/demo_02.ks
end
