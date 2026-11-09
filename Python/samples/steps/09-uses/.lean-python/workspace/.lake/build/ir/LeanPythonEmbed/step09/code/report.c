// Lean compiler output
// Module: LeanPythonEmbed.step09.code.report
// Imports: public import Init public meta import Init public import LeanPythonEmbed.step09.code.shapes
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
lean_object* lean_nat_add(lean_object*, lean_object*);
lean_object* l_List_reverse___redArg(lean_object*);
lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area(lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_mapTR_loop___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__1(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__1___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report_totalArea(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_largest_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_largest_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report_largest(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report_largest___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_mapTR_loop___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__0(lean_object* v_a_1_, lean_object* v_a_2_){
_start:
{
if (lean_obj_tag(v_a_1_) == 0)
{
lean_object* v___x_3_; 
v___x_3_ = l_List_reverse___redArg(v_a_2_);
return v___x_3_;
}
else
{
lean_object* v_head_4_; lean_object* v_tail_5_; lean_object* v___x_7_; uint8_t v_isShared_8_; uint8_t v_isSharedCheck_14_; 
v_head_4_ = lean_ctor_get(v_a_1_, 0);
v_tail_5_ = lean_ctor_get(v_a_1_, 1);
v_isSharedCheck_14_ = !lean_is_exclusive(v_a_1_);
if (v_isSharedCheck_14_ == 0)
{
v___x_7_ = v_a_1_;
v_isShared_8_ = v_isSharedCheck_14_;
goto v_resetjp_6_;
}
else
{
lean_inc(v_tail_5_);
lean_inc(v_head_4_);
lean_dec(v_a_1_);
v___x_7_ = lean_box(0);
v_isShared_8_ = v_isSharedCheck_14_;
goto v_resetjp_6_;
}
v_resetjp_6_:
{
lean_object* v___x_9_; lean_object* v___x_11_; 
v___x_9_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area(v_head_4_);
lean_dec(v_head_4_);
if (v_isShared_8_ == 0)
{
lean_ctor_set(v___x_7_, 1, v_a_2_);
lean_ctor_set(v___x_7_, 0, v___x_9_);
v___x_11_ = v___x_7_;
goto v_reusejp_10_;
}
else
{
lean_object* v_reuseFailAlloc_13_; 
v_reuseFailAlloc_13_ = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(v_reuseFailAlloc_13_, 0, v___x_9_);
lean_ctor_set(v_reuseFailAlloc_13_, 1, v_a_2_);
v___x_11_ = v_reuseFailAlloc_13_;
goto v_reusejp_10_;
}
v_reusejp_10_:
{
v_a_1_ = v_tail_5_;
v_a_2_ = v___x_11_;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__1(lean_object* v_x_15_, lean_object* v_x_16_){
_start:
{
if (lean_obj_tag(v_x_16_) == 0)
{
return v_x_15_;
}
else
{
lean_object* v_head_17_; lean_object* v_tail_18_; lean_object* v___x_19_; 
v_head_17_ = lean_ctor_get(v_x_16_, 0);
v_tail_18_ = lean_ctor_get(v_x_16_, 1);
v___x_19_ = lean_nat_add(v_x_15_, v_head_17_);
lean_dec(v_x_15_);
v_x_15_ = v___x_19_;
v_x_16_ = v_tail_18_;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__1___boxed(lean_object* v_x_21_, lean_object* v_x_22_){
_start:
{
lean_object* v_res_23_; 
v_res_23_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__1(v_x_21_, v_x_22_);
lean_dec(v_x_22_);
return v_res_23_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report_totalArea(lean_object* v_xs_24_){
_start:
{
lean_object* v___x_25_; lean_object* v___x_26_; lean_object* v___x_27_; lean_object* v___x_28_; 
v___x_25_ = lean_unsigned_to_nat(0u);
v___x_26_ = lean_box(0);
v___x_27_ = lp_lean_x2dpython_x2dworkspace_List_mapTR_loop___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__0(v_xs_24_, v___x_26_);
v___x_28_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_totalArea_spec__1(v___x_25_, v___x_27_);
lean_dec(v___x_27_);
return v___x_28_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_largest_spec__0(lean_object* v_x_29_, lean_object* v_x_30_){
_start:
{
if (lean_obj_tag(v_x_30_) == 0)
{
return v_x_29_;
}
else
{
if (lean_obj_tag(v_x_29_) == 0)
{
lean_object* v_head_31_; lean_object* v_tail_32_; lean_object* v___x_33_; 
v_head_31_ = lean_ctor_get(v_x_30_, 0);
v_tail_32_ = lean_ctor_get(v_x_30_, 1);
lean_inc(v_head_31_);
v___x_33_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v___x_33_, 0, v_head_31_);
v_x_29_ = v___x_33_;
v_x_30_ = v_tail_32_;
goto _start;
}
else
{
lean_object* v_head_35_; lean_object* v_tail_36_; lean_object* v_val_37_; lean_object* v___x_38_; lean_object* v___x_39_; uint8_t v___x_40_; 
v_head_35_ = lean_ctor_get(v_x_30_, 0);
v_tail_36_ = lean_ctor_get(v_x_30_, 1);
v_val_37_ = lean_ctor_get(v_x_29_, 0);
v___x_38_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area(v_val_37_);
v___x_39_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area(v_head_35_);
v___x_40_ = lean_nat_dec_lt(v___x_38_, v___x_39_);
lean_dec(v___x_39_);
lean_dec(v___x_38_);
if (v___x_40_ == 0)
{
v_x_30_ = v_tail_36_;
goto _start;
}
else
{
lean_object* v___x_43_; uint8_t v_isShared_44_; uint8_t v_isSharedCheck_49_; 
v_isSharedCheck_49_ = !lean_is_exclusive(v_x_29_);
if (v_isSharedCheck_49_ == 0)
{
lean_object* v_unused_50_; 
v_unused_50_ = lean_ctor_get(v_x_29_, 0);
lean_dec(v_unused_50_);
v___x_43_ = v_x_29_;
v_isShared_44_ = v_isSharedCheck_49_;
goto v_resetjp_42_;
}
else
{
lean_dec(v_x_29_);
v___x_43_ = lean_box(0);
v_isShared_44_ = v_isSharedCheck_49_;
goto v_resetjp_42_;
}
v_resetjp_42_:
{
lean_object* v___x_46_; 
lean_inc(v_head_35_);
if (v_isShared_44_ == 0)
{
lean_ctor_set(v___x_43_, 0, v_head_35_);
v___x_46_ = v___x_43_;
goto v_reusejp_45_;
}
else
{
lean_object* v_reuseFailAlloc_48_; 
v_reuseFailAlloc_48_ = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(v_reuseFailAlloc_48_, 0, v_head_35_);
v___x_46_ = v_reuseFailAlloc_48_;
goto v_reusejp_45_;
}
v_reusejp_45_:
{
v_x_29_ = v___x_46_;
v_x_30_ = v_tail_36_;
goto _start;
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_largest_spec__0___boxed(lean_object* v_x_51_, lean_object* v_x_52_){
_start:
{
lean_object* v_res_53_; 
v_res_53_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_largest_spec__0(v_x_51_, v_x_52_);
lean_dec(v_x_52_);
return v_res_53_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report_largest(lean_object* v_xs_54_){
_start:
{
lean_object* v___x_55_; lean_object* v___x_56_; 
v___x_55_ = lean_box(0);
v___x_56_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_step09_code_report_largest_spec__0(v___x_55_, v_xs_54_);
return v___x_56_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report_largest___boxed(lean_object* v_xs_57_){
_start:
{
lean_object* v_res_58_; 
v_res_58_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report_largest(v_xs_57_);
lean_dec(v_xs_57_);
return v_res_58_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_report(uint8_t builtin) {
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
res = initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
