// Lean compiler output
// Module: LeanPythonEmbed.step03.code.m
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
lean_object* lean_int_add(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
lean_object* lean_nat_abs(lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_add(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_add___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_norm1(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_norm1___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_width(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_width___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_shift(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_shift___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_add(lean_object* v_p_1_, lean_object* v_q_2_){
_start:
{
lean_object* v_x_3_; lean_object* v_y_4_; lean_object* v_x_5_; lean_object* v_y_6_; lean_object* v___x_8_; uint8_t v_isShared_9_; uint8_t v_isSharedCheck_15_; 
v_x_3_ = lean_ctor_get(v_p_1_, 0);
v_y_4_ = lean_ctor_get(v_p_1_, 1);
v_x_5_ = lean_ctor_get(v_q_2_, 0);
v_y_6_ = lean_ctor_get(v_q_2_, 1);
v_isSharedCheck_15_ = !lean_is_exclusive(v_q_2_);
if (v_isSharedCheck_15_ == 0)
{
v___x_8_ = v_q_2_;
v_isShared_9_ = v_isSharedCheck_15_;
goto v_resetjp_7_;
}
else
{
lean_inc(v_y_6_);
lean_inc(v_x_5_);
lean_dec(v_q_2_);
v___x_8_ = lean_box(0);
v_isShared_9_ = v_isSharedCheck_15_;
goto v_resetjp_7_;
}
v_resetjp_7_:
{
lean_object* v___x_10_; lean_object* v___x_11_; lean_object* v___x_13_; 
v___x_10_ = lean_int_add(v_x_3_, v_x_5_);
lean_dec(v_x_5_);
v___x_11_ = lean_int_add(v_y_4_, v_y_6_);
lean_dec(v_y_6_);
if (v_isShared_9_ == 0)
{
lean_ctor_set(v___x_8_, 1, v___x_11_);
lean_ctor_set(v___x_8_, 0, v___x_10_);
v___x_13_ = v___x_8_;
goto v_reusejp_12_;
}
else
{
lean_object* v_reuseFailAlloc_14_; 
v_reuseFailAlloc_14_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_14_, 0, v___x_10_);
lean_ctor_set(v_reuseFailAlloc_14_, 1, v___x_11_);
v___x_13_ = v_reuseFailAlloc_14_;
goto v_reusejp_12_;
}
v_reusejp_12_:
{
return v___x_13_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_add___boxed(lean_object* v_p_16_, lean_object* v_q_17_){
_start:
{
lean_object* v_res_18_; 
v_res_18_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_add(v_p_16_, v_q_17_);
lean_dec_ref(v_p_16_);
return v_res_18_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_norm1(lean_object* v_p_19_){
_start:
{
lean_object* v_x_20_; lean_object* v_y_21_; lean_object* v___x_22_; lean_object* v___x_23_; lean_object* v___x_24_; 
v_x_20_ = lean_ctor_get(v_p_19_, 0);
v_y_21_ = lean_ctor_get(v_p_19_, 1);
v___x_22_ = lean_nat_abs(v_x_20_);
v___x_23_ = lean_nat_abs(v_y_21_);
v___x_24_ = lean_nat_add(v___x_22_, v___x_23_);
lean_dec(v___x_23_);
lean_dec(v___x_22_);
return v___x_24_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_norm1___boxed(lean_object* v_p_25_){
_start:
{
lean_object* v_res_26_; 
v_res_26_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Point_norm1(v_p_25_);
lean_dec_ref(v_p_25_);
return v_res_26_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_width(lean_object* v_r_27_){
_start:
{
lean_object* v_lo_28_; lean_object* v_hi_29_; lean_object* v___x_30_; 
v_lo_28_ = lean_ctor_get(v_r_27_, 0);
v_hi_29_ = lean_ctor_get(v_r_27_, 1);
v___x_30_ = lean_nat_sub(v_hi_29_, v_lo_28_);
return v___x_30_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_width___boxed(lean_object* v_r_31_){
_start:
{
lean_object* v_res_32_; 
v_res_32_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_width(v_r_31_);
lean_dec_ref(v_r_31_);
return v_res_32_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_shift(lean_object* v_r_33_, lean_object* v_k_34_){
_start:
{
lean_object* v_lo_35_; lean_object* v_hi_36_; lean_object* v___x_38_; uint8_t v_isShared_39_; uint8_t v_isSharedCheck_45_; 
v_lo_35_ = lean_ctor_get(v_r_33_, 0);
v_hi_36_ = lean_ctor_get(v_r_33_, 1);
v_isSharedCheck_45_ = !lean_is_exclusive(v_r_33_);
if (v_isSharedCheck_45_ == 0)
{
v___x_38_ = v_r_33_;
v_isShared_39_ = v_isSharedCheck_45_;
goto v_resetjp_37_;
}
else
{
lean_inc(v_hi_36_);
lean_inc(v_lo_35_);
lean_dec(v_r_33_);
v___x_38_ = lean_box(0);
v_isShared_39_ = v_isSharedCheck_45_;
goto v_resetjp_37_;
}
v_resetjp_37_:
{
lean_object* v___x_40_; lean_object* v___x_41_; lean_object* v___x_43_; 
v___x_40_ = lean_nat_add(v_lo_35_, v_k_34_);
lean_dec(v_lo_35_);
v___x_41_ = lean_nat_add(v_hi_36_, v_k_34_);
lean_dec(v_hi_36_);
if (v_isShared_39_ == 0)
{
lean_ctor_set(v___x_38_, 1, v___x_41_);
lean_ctor_set(v___x_38_, 0, v___x_40_);
v___x_43_ = v___x_38_;
goto v_reusejp_42_;
}
else
{
lean_object* v_reuseFailAlloc_44_; 
v_reuseFailAlloc_44_ = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(v_reuseFailAlloc_44_, 0, v___x_40_);
lean_ctor_set(v_reuseFailAlloc_44_, 1, v___x_41_);
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
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_shift___boxed(lean_object* v_r_46_, lean_object* v_k_47_){
_start:
{
lean_object* v_res_48_; 
v_res_48_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m_Range_shift(v_r_46_, v_k_47_);
lean_dec(v_k_47_);
return v_res_48_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step03_code_m(uint8_t builtin) {
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
