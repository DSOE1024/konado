---
title: 씬 기반 리소스
order: 8
---

# 씬 기반 리소스

캐릭터와 배경 항목은 `PackedScene`을 참조합니다. 씬에는 이미지, 비디오, Spine, Live2D, 셰이더 또는 사용자 노드를 넣을 수 있습니다.

캐릭터 씬은 `KND_CharacterSceneBase`를 상속하고 `_apply_status(resolved_status_name, original_status_name)`를 재정의합니다. 시스템은 `apply_status(status_name)`를 통해 이 메서드를 호출합니다. 기본적으로 `actor change`는 캐릭터 마운트를 페이드아웃하고 상태를 적용한 뒤 페이드인하며, 캐릭터 씬을 복제하지 않습니다. 전환이 끝난 뒤 스토리 실행을 계속합니다. 설정 방법은 [액터 상태 전환](../script/actor/actor-change-state.md)을 참고하세요. 무대 동작은 KS 동작 이름과 같은 애니메이션을 가진 `KND_ActorMotionLayer` 씬에 둡니다.

배경 씬은 `KND_BackgroundSceneBase`를 상속합니다. 카메라 명령을 사용하려면 고유한 이름의 `KonadoCamera2D`를 추가하세요. 기본 전환은 `KND_BackgroundTransitionLayer`가 처리하며, 기본적으로 `SubViewport`를 통해 전체 씬을 캡처합니다. 최종 화면이 수정되지 않은 단일 원본 텍스처와 완전히 동일한 경우에만 `DIRECT_TEXTURE`를 선택하세요. 레이아웃, 변형, 카메라, 애니메이션, 머티리얼, 색조 또는 여러 그리기 노드를 사용하는 배경은 `VIEWPORT_CAPTURE`를 유지해야 합니다.
