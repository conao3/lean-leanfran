// Lean compiler output
// Module: LeanPythonEmbed.step02.code.m
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
uint8_t lean_int_dec_le(lean_object*, lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_sumTo(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_sumTo___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter___redArg___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_clamp(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_clamp___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_sumTo(lean_object* v_x_1_){
_start:
{
lean_object* v_zero_2_; uint8_t v_isZero_3_; 
v_zero_2_ = lean_unsigned_to_nat(0u);
v_isZero_3_ = lean_nat_dec_eq(v_x_1_, v_zero_2_);
if (v_isZero_3_ == 1)
{
return v_zero_2_;
}
else
{
lean_object* v_one_4_; lean_object* v_n_5_; lean_object* v___x_6_; lean_object* v___x_7_; lean_object* v___x_8_; 
v_one_4_ = lean_unsigned_to_nat(1u);
v_n_5_ = lean_nat_sub(v_x_1_, v_one_4_);
v___x_6_ = lean_nat_add(v_n_5_, v_one_4_);
v___x_7_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_sumTo(v_n_5_);
lean_dec(v_n_5_);
v___x_8_ = lean_nat_add(v___x_6_, v___x_7_);
lean_dec(v___x_7_);
lean_dec(v___x_6_);
return v___x_8_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_sumTo___boxed(lean_object* v_x_9_){
_start:
{
lean_object* v_res_10_; 
v_res_10_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_sumTo(v_x_9_);
lean_dec(v_x_9_);
return v_res_10_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter___redArg(lean_object* v_x_11_, lean_object* v_h__1_12_, lean_object* v_h__2_13_){
_start:
{
lean_object* v_zero_14_; uint8_t v_isZero_15_; 
v_zero_14_ = lean_unsigned_to_nat(0u);
v_isZero_15_ = lean_nat_dec_eq(v_x_11_, v_zero_14_);
if (v_isZero_15_ == 1)
{
lean_object* v___x_16_; lean_object* v___x_17_; 
lean_dec(v_h__2_13_);
v___x_16_ = lean_box(0);
v___x_17_ = lean_apply_1(v_h__1_12_, v___x_16_);
return v___x_17_;
}
else
{
lean_object* v_one_18_; lean_object* v_n_19_; lean_object* v___x_20_; 
lean_dec(v_h__1_12_);
v_one_18_ = lean_unsigned_to_nat(1u);
v_n_19_ = lean_nat_sub(v_x_11_, v_one_18_);
v___x_20_ = lean_apply_1(v_h__2_13_, v_n_19_);
return v___x_20_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter___redArg___boxed(lean_object* v_x_21_, lean_object* v_h__1_22_, lean_object* v_h__2_23_){
_start:
{
lean_object* v_res_24_; 
v_res_24_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter___redArg(v_x_21_, v_h__1_22_, v_h__2_23_);
lean_dec(v_x_21_);
return v_res_24_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter(lean_object* v_motive_25_, lean_object* v_x_26_, lean_object* v_h__1_27_, lean_object* v_h__2_28_){
_start:
{
lean_object* v_zero_29_; uint8_t v_isZero_30_; 
v_zero_29_ = lean_unsigned_to_nat(0u);
v_isZero_30_ = lean_nat_dec_eq(v_x_26_, v_zero_29_);
if (v_isZero_30_ == 1)
{
lean_object* v___x_31_; lean_object* v___x_32_; 
lean_dec(v_h__2_28_);
v___x_31_ = lean_box(0);
v___x_32_ = lean_apply_1(v_h__1_27_, v___x_31_);
return v___x_32_;
}
else
{
lean_object* v_one_33_; lean_object* v_n_34_; lean_object* v___x_35_; 
lean_dec(v_h__1_27_);
v_one_33_ = lean_unsigned_to_nat(1u);
v_n_34_ = lean_nat_sub(v_x_26_, v_one_33_);
v___x_35_ = lean_apply_1(v_h__2_28_, v_n_34_);
return v___x_35_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter___boxed(lean_object* v_motive_36_, lean_object* v_x_37_, lean_object* v_h__1_38_, lean_object* v_h__2_39_){
_start:
{
lean_object* v_res_40_; 
v_res_40_ = lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_step02_code_m_0__LeanPythonEmbed_step02_code_m_sumTo_match__1_splitter(v_motive_36_, v_x_37_, v_h__1_38_, v_h__2_39_);
lean_dec(v_x_37_);
return v_res_40_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_clamp(lean_object* v_lo_41_, lean_object* v_hi_42_, lean_object* v_x_43_){
_start:
{
lean_object* v___y_45_; uint8_t v___x_47_; 
v___x_47_ = lean_int_dec_le(v_hi_42_, v_x_43_);
if (v___x_47_ == 0)
{
v___y_45_ = v_x_43_;
goto v___jp_44_;
}
else
{
v___y_45_ = v_hi_42_;
goto v___jp_44_;
}
v___jp_44_:
{
uint8_t v___x_46_; 
v___x_46_ = lean_int_dec_le(v_lo_41_, v___y_45_);
if (v___x_46_ == 0)
{
lean_inc(v_lo_41_);
return v_lo_41_;
}
else
{
lean_inc(v___y_45_);
return v___y_45_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_clamp___boxed(lean_object* v_lo_48_, lean_object* v_hi_49_, lean_object* v_x_50_){
_start:
{
lean_object* v_res_51_; 
v_res_51_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m_clamp(v_lo_48_, v_hi_49_, v_x_50_);
lean_dec(v_x_50_);
lean_dec(v_hi_49_);
lean_dec(v_lo_48_);
return v_res_51_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step02_code_m(uint8_t builtin) {
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
