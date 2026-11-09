// Lean compiler output
// Module: LeanPythonEmbed.step07.code.m
// Imports: public import Init public meta import Init
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
lean_object* l_IO_FS_readFile(lean_object*);
lean_object* l_String_splitOnAux(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* l_List_lengthTR___redArg(lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* lean_mk_empty_array_with_capacity(lean_object*);
lean_object* lean_array_push(lean_object*, lean_object*);
lean_object* l_IO_Process_output(lean_object*, lean_object*);
lean_object* lean_string_utf8_byte_size(lean_object*);
lean_object* l_String_Slice_Pos_revSkipWhile___at___00String_Slice_trimRight_spec__0(lean_object*, lean_object*);
lean_object* l_String_Slice_toString(lean_object*);
lean_object* lean_io_prim_handle_mk(lean_object*, uint8_t);
lean_object* l_IO_FS_Handle_putStrLn(lean_object*, lean_object*);
static const lean_string_object lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "\n"};
static const lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines___closed__0 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines___closed__0_value;
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_appendLine(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_appendLine___boxed(lean_object*, lean_object*, lean_object*);
static const lean_ctor_object lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*0 + 8, .m_other = 0, .m_tag = 0}, .m_objs = {LEAN_SCALAR_PTR_LITERAL(1, 1, 1, 0, 0, 0, 0, 0)}};
static const lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__0 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__0_value;
static const lean_string_object lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = "echo"};
static const lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__1 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__1_value;
static const lean_array_object lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_array_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 246}, .m_size = 0, .m_capacity = 0, .m_data = {}};
static const lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__2 = (const lean_object*)&lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__2_value;
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines(lean_object* v_path_2_){
_start:
{
lean_object* v___x_4_; 
v___x_4_ = l_IO_FS_readFile(v_path_2_);
if (lean_obj_tag(v___x_4_) == 0)
{
lean_object* v_a_5_; lean_object* v___x_7_; uint8_t v_isShared_8_; uint8_t v_isSharedCheck_19_; 
v_a_5_ = lean_ctor_get(v___x_4_, 0);
v_isSharedCheck_19_ = !lean_is_exclusive(v___x_4_);
if (v_isSharedCheck_19_ == 0)
{
v___x_7_ = v___x_4_;
v_isShared_8_ = v_isSharedCheck_19_;
goto v_resetjp_6_;
}
else
{
lean_inc(v_a_5_);
lean_dec(v___x_4_);
v___x_7_ = lean_box(0);
v_isShared_8_ = v_isSharedCheck_19_;
goto v_resetjp_6_;
}
v_resetjp_6_:
{
lean_object* v___x_9_; lean_object* v___x_10_; lean_object* v___x_11_; lean_object* v___x_12_; lean_object* v___x_13_; lean_object* v___x_14_; lean_object* v___x_15_; lean_object* v___x_17_; 
v___x_9_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines___closed__0));
v___x_10_ = lean_unsigned_to_nat(0u);
v___x_11_ = lean_box(0);
v___x_12_ = l_String_splitOnAux(v_a_5_, v___x_9_, v___x_10_, v___x_10_, v___x_10_, v___x_11_);
lean_dec(v_a_5_);
v___x_13_ = l_List_lengthTR___redArg(v___x_12_);
lean_dec(v___x_12_);
v___x_14_ = lean_unsigned_to_nat(1u);
v___x_15_ = lean_nat_sub(v___x_13_, v___x_14_);
lean_dec(v___x_13_);
if (v_isShared_8_ == 0)
{
lean_ctor_set(v___x_7_, 0, v___x_15_);
v___x_17_ = v___x_7_;
goto v_reusejp_16_;
}
else
{
lean_object* v_reuseFailAlloc_18_; 
v_reuseFailAlloc_18_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_18_, 0, v___x_15_);
v___x_17_ = v_reuseFailAlloc_18_;
goto v_reusejp_16_;
}
v_reusejp_16_:
{
return v___x_17_;
}
}
}
else
{
lean_object* v_a_20_; lean_object* v___x_22_; uint8_t v_isShared_23_; uint8_t v_isSharedCheck_27_; 
v_a_20_ = lean_ctor_get(v___x_4_, 0);
v_isSharedCheck_27_ = !lean_is_exclusive(v___x_4_);
if (v_isSharedCheck_27_ == 0)
{
v___x_22_ = v___x_4_;
v_isShared_23_ = v_isSharedCheck_27_;
goto v_resetjp_21_;
}
else
{
lean_inc(v_a_20_);
lean_dec(v___x_4_);
v___x_22_ = lean_box(0);
v_isShared_23_ = v_isSharedCheck_27_;
goto v_resetjp_21_;
}
v_resetjp_21_:
{
lean_object* v___x_25_; 
if (v_isShared_23_ == 0)
{
v___x_25_ = v___x_22_;
goto v_reusejp_24_;
}
else
{
lean_object* v_reuseFailAlloc_26_; 
v_reuseFailAlloc_26_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_26_, 0, v_a_20_);
v___x_25_ = v_reuseFailAlloc_26_;
goto v_reusejp_24_;
}
v_reusejp_24_:
{
return v___x_25_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines___boxed(lean_object* v_path_28_, lean_object* v_a_29_){
_start:
{
lean_object* v_res_30_; 
v_res_30_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_countLines(v_path_28_);
lean_dec_ref(v_path_28_);
return v_res_30_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_appendLine(lean_object* v_path_31_, lean_object* v_line_32_){
_start:
{
uint8_t v___x_34_; lean_object* v___x_35_; 
v___x_34_ = 4;
v___x_35_ = lean_io_prim_handle_mk(v_path_31_, v___x_34_);
if (lean_obj_tag(v___x_35_) == 0)
{
lean_object* v_a_36_; lean_object* v___x_37_; 
v_a_36_ = lean_ctor_get(v___x_35_, 0);
lean_inc(v_a_36_);
lean_dec_ref_known(v___x_35_, 1);
v___x_37_ = l_IO_FS_Handle_putStrLn(v_a_36_, v_line_32_);
lean_dec(v_a_36_);
return v___x_37_;
}
else
{
lean_object* v_a_38_; lean_object* v___x_40_; uint8_t v_isShared_41_; uint8_t v_isSharedCheck_45_; 
lean_dec_ref(v_line_32_);
v_a_38_ = lean_ctor_get(v___x_35_, 0);
v_isSharedCheck_45_ = !lean_is_exclusive(v___x_35_);
if (v_isSharedCheck_45_ == 0)
{
v___x_40_ = v___x_35_;
v_isShared_41_ = v_isSharedCheck_45_;
goto v_resetjp_39_;
}
else
{
lean_inc(v_a_38_);
lean_dec(v___x_35_);
v___x_40_ = lean_box(0);
v_isShared_41_ = v_isSharedCheck_45_;
goto v_resetjp_39_;
}
v_resetjp_39_:
{
lean_object* v___x_43_; 
if (v_isShared_41_ == 0)
{
v___x_43_ = v___x_40_;
goto v_reusejp_42_;
}
else
{
lean_object* v_reuseFailAlloc_44_; 
v_reuseFailAlloc_44_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_44_, 0, v_a_38_);
v___x_43_ = v_reuseFailAlloc_44_;
goto v_reusejp_42_;
}
v_reusejp_42_:
{
return v___x_43_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_appendLine___boxed(lean_object* v_path_46_, lean_object* v_line_47_, lean_object* v_a_48_){
_start:
{
lean_object* v_res_49_; 
v_res_49_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_appendLine(v_path_46_, v_line_47_);
lean_dec_ref(v_path_46_);
return v_res_49_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho(lean_object* v_msg_55_){
_start:
{
lean_object* v___x_57_; lean_object* v___x_58_; lean_object* v___x_59_; lean_object* v___x_60_; lean_object* v___x_61_; lean_object* v___x_62_; lean_object* v___x_63_; lean_object* v___x_64_; uint8_t v___x_65_; uint8_t v___x_66_; lean_object* v___x_67_; lean_object* v___x_68_; 
v___x_57_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__0));
v___x_58_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__1));
v___x_59_ = lean_unsigned_to_nat(1u);
v___x_60_ = lean_mk_empty_array_with_capacity(v___x_59_);
v___x_61_ = lean_array_push(v___x_60_, v_msg_55_);
v___x_62_ = lean_box(0);
v___x_63_ = lean_unsigned_to_nat(0u);
v___x_64_ = ((lean_object*)(lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___closed__2));
v___x_65_ = 1;
v___x_66_ = 0;
v___x_67_ = lean_alloc_ctor(0, 5, 2);
lean_ctor_set(v___x_67_, 0, v___x_57_);
lean_ctor_set(v___x_67_, 1, v___x_58_);
lean_ctor_set(v___x_67_, 2, v___x_61_);
lean_ctor_set(v___x_67_, 3, v___x_62_);
lean_ctor_set(v___x_67_, 4, v___x_64_);
lean_ctor_set_uint8(v___x_67_, sizeof(void*)*5, v___x_65_);
lean_ctor_set_uint8(v___x_67_, sizeof(void*)*5 + 1, v___x_66_);
v___x_68_ = l_IO_Process_output(v___x_67_, v___x_62_);
if (lean_obj_tag(v___x_68_) == 0)
{
lean_object* v_a_69_; lean_object* v___x_71_; uint8_t v_isShared_72_; uint8_t v_isSharedCheck_82_; 
v_a_69_ = lean_ctor_get(v___x_68_, 0);
v_isSharedCheck_82_ = !lean_is_exclusive(v___x_68_);
if (v_isSharedCheck_82_ == 0)
{
v___x_71_ = v___x_68_;
v_isShared_72_ = v_isSharedCheck_82_;
goto v_resetjp_70_;
}
else
{
lean_inc(v_a_69_);
lean_dec(v___x_68_);
v___x_71_ = lean_box(0);
v_isShared_72_ = v_isSharedCheck_82_;
goto v_resetjp_70_;
}
v_resetjp_70_:
{
lean_object* v_stdout_73_; lean_object* v___x_74_; lean_object* v___x_75_; lean_object* v___x_76_; lean_object* v___x_77_; lean_object* v___x_78_; lean_object* v___x_80_; 
v_stdout_73_ = lean_ctor_get(v_a_69_, 0);
lean_inc_ref_n(v_stdout_73_, 2);
lean_dec(v_a_69_);
v___x_74_ = lean_string_utf8_byte_size(v_stdout_73_);
v___x_75_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_75_, 0, v_stdout_73_);
lean_ctor_set(v___x_75_, 1, v___x_63_);
lean_ctor_set(v___x_75_, 2, v___x_74_);
v___x_76_ = l_String_Slice_Pos_revSkipWhile___at___00String_Slice_trimRight_spec__0(v___x_75_, v___x_74_);
lean_dec_ref_known(v___x_75_, 3);
v___x_77_ = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(v___x_77_, 0, v_stdout_73_);
lean_ctor_set(v___x_77_, 1, v___x_63_);
lean_ctor_set(v___x_77_, 2, v___x_76_);
v___x_78_ = l_String_Slice_toString(v___x_77_);
lean_dec_ref_known(v___x_77_, 3);
if (v_isShared_72_ == 0)
{
lean_ctor_set(v___x_71_, 0, v___x_78_);
v___x_80_ = v___x_71_;
goto v_reusejp_79_;
}
else
{
lean_object* v_reuseFailAlloc_81_; 
v_reuseFailAlloc_81_ = lean_alloc_ctor(0, 1, 0);
lean_ctor_set(v_reuseFailAlloc_81_, 0, v___x_78_);
v___x_80_ = v_reuseFailAlloc_81_;
goto v_reusejp_79_;
}
v_reusejp_79_:
{
return v___x_80_;
}
}
}
else
{
lean_object* v_a_83_; lean_object* v___x_85_; uint8_t v_isShared_86_; uint8_t v_isSharedCheck_90_; 
v_a_83_ = lean_ctor_get(v___x_68_, 0);
v_isSharedCheck_90_ = !lean_is_exclusive(v___x_68_);
if (v_isSharedCheck_90_ == 0)
{
v___x_85_ = v___x_68_;
v_isShared_86_ = v_isSharedCheck_90_;
goto v_resetjp_84_;
}
else
{
lean_inc(v_a_83_);
lean_dec(v___x_68_);
v___x_85_ = lean_box(0);
v_isShared_86_ = v_isSharedCheck_90_;
goto v_resetjp_84_;
}
v_resetjp_84_:
{
lean_object* v___x_88_; 
if (v_isShared_86_ == 0)
{
v___x_88_ = v___x_85_;
goto v_reusejp_87_;
}
else
{
lean_object* v_reuseFailAlloc_89_; 
v_reuseFailAlloc_89_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_89_, 0, v_a_83_);
v___x_88_ = v_reuseFailAlloc_89_;
goto v_reusejp_87_;
}
v_reusejp_87_:
{
return v___x_88_;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho___boxed(lean_object* v_msg_91_, lean_object* v_a_92_){
_start:
{
lean_object* v_res_93_; 
v_res_93_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m_runEcho(v_msg_91_);
return v_res_93_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step07_code_m(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
lean_initialize_runtime_module();
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
