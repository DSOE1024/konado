# 示例 11｜跳转到不存在的剧本（编译期拦截）
# 期望：编译期诊断（不是运行期错误码）
#   错误：res://sample/error_gallery/does_not_exist.ks [行：1] jump 目标剧本 '...' 不存在
# 说明：Konado 在编译阶段就校验 jump 目标是否存在，因此这类问题不会进入运行期失败面板；
#      运行期跳转失败会报 SC-002 script.jump_load_failed。
jump res://sample/error_gallery/does_not_exist.ks
end
