---
title: 씬 기반 리소스
order: 8
---

# 씬 기반 리소스

캐릭터와 배경 항목은 `PackedScene`을 참조합니다. 씬에는 이미지, 비디오, Spine, Live2D, 셰이더 또는 사용자 노드를 넣을 수 있습니다.

캐릭터 씬은 `KND_CharacterSceneBase`를 상속하고 `apply_state(state_name)`에서 상태를 적용합니다. 무대 동작은 KS 동작 이름과 같은 애니메이션을 가진 `KND_ActorMotionLayer` 씬에 둡니다.

배경 씬은 `KND_BackgroundSceneBase`를 상속합니다. 카메라 명령을 사용하려면 고유한 이름의 `KonadoCamera2D`를 추가하세요. 기본 전환은 `KND_BackgroundTransitionLayer`가 처리합니다.
