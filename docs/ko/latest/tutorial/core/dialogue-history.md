---
title: 대화 기록 (백로그)
order: 8
---

# 대화 기록 (백로그)

대화 기록(백로그)은 플레이어가 이미 읽은 대사를 다시 확인할 수 있게 해 줍니다. 런타임 서비스 `KonadoDialogueHistory`가 관리하며, 기본 대화 템플릿에는 바로 열 수 있는 기록 패널이 포함되어 있습니다.

## 동작 규칙

- 기록은 **세션 단위**입니다. 메모리에만 보관되며 세이브 파일에 기록되지 않으므로 기존 세이브 형식은 바뀌지 않고 이전 세이브도 그대로 불러올 수 있습니다.
- 기록은 **원자적 트랜잭션** 단위입니다. 가상 머신이 정상적으로 커밋한 대화 명령만 기록되며, 취소·실패·대체된 명령은 흔적을 남기지 않습니다.
- 화면에 표시되었지만 아직 진행하지 않은 줄은 **보류 항목**으로 노출되어, 패널을 열 때 현재 대사를 보여 줄 수 있습니다.
- 항목 수는 `max_dialogue_history_entries`(기본 `256`)로 제한되며, 초과하면 가장 오래된 항목부터 제거됩니다.

## 런타임 API

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

```gdscript
# 시간 순서의 항목. include_pending이 true이면 아직 진행하지 않은 현재 줄도 포함
var entries: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, true)

# 커밋된 항목만
var committed: Array[Dictionary] = dialogue_manager.dialogue_history.entries(0, false)

# 커밋된 항목 수
var count: int = dialogue_manager.dialogue_history.size()

# 기록 비우기(보류 항목도 함께 폐기)
dialogue_manager.dialogue_history.clear()
```

각 항목에는 `kind`(`dialogue`, `choice` 또는 `screen_text`), `speaker`, `text`, `options`(`choice`에만 해당, 제시된 모든 선택지), `instruction_id`, `shot_path`, `line`, `serial`, `pending` 필드가 있습니다.

### 실시간 알림

```gdscript
dialogue_manager.dialogue_history.entry_committed.connect(
    func(entry: Dictionary) -> void:
        print("새 대사: ", entry["speaker"], entry["text"])
)
```

## 선택 기록

플레이어의 선택도 기록됩니다. 분기를 선택하면 `kind`가 `choice`인 항목이 기록되며, `text`는 **선택한 선택지**, `options`는 **그때 제시된 모든 선택지**입니다. 기본 패널은 모든 선택지를 나열하고 선택된 항목을 `▶`로 강조합니다. 선택도 대사와 동일한 원자적 트랜잭션을 따르며, 커밋된 선택만 기록에 남습니다.

## 전체 화면 텍스트 기록

전체 화면 텍스트(`screentext` 명령, NVL 본문)는 `kind`가 `screen_text`인 하나의 항목으로 기록됩니다. `text`는 모든 줄을 줄바꿈으로 연결한 문자열이고 `lines`는 줄별 텍스트 배열입니다. 기본 패널은 줄마다 표시합니다. 대사와 마찬가지로 원자적 트랜잭션을 따르며, 끝까지 재생되어 커밋된 뒤에만 기록에 들어갑니다.

## 트랜잭션과 롤백

기록은 가상 머신의 원자적 트랜잭션과 일대일로 대응합니다. 기본 `TRIM` 정책은 롤백이나 체크포인트 복원 후 기록을 타임라인과 일치시켜, 되돌린 대사를 기록에서 제거합니다. 본 적 있는 내용을 모두 남기는 고전적 비주얼 노벨 동작을 원하면 `KEEP`을 사용하세요.

```gdscript
dialogue_manager.dialogue_history.rollback_policy = (
    KonadoDialogueHistory.RollbackPolicy.KEEP
)
```

## 기본 템플릿

기본 대화 템플릿은 기능 표시줄에 "백로그" 버튼을 추가하고 `res://addons/konado/templates/default/backlog_panel.tscn`(스크립트: `res://addons/konado/runtime/ui/backlog/konado_backlog_panel.gd`)을 생성합니다. 사용자 지정 템플릿에서 이 내보내기를 설정하지 않으면 기능은 자동으로 비활성화되며 다른 동작에 영향을 주지 않습니다.
