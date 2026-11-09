// Lean compiler output
// Module: LeanPythonEmbed.step09.code.shapes
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
lean_object* lean_nat_mul(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorIdx(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_square_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_square_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_rect_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_rect_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorIdx(lean_object* v_x_1_){
_start:
{
if (lean_obj_tag(v_x_1_) == 0)
{
lean_object* v___x_2_; 
v___x_2_ = lean_unsigned_to_nat(0u);
return v___x_2_;
}
else
{
lean_object* v___x_3_; 
v___x_3_ = lean_unsigned_to_nat(1u);
return v___x_3_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorIdx___boxed(lean_object* v_x_4_){
_start:
{
lean_object* v_res_5_; 
v_res_5_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorIdx(v_x_4_);
lean_dec_ref(v_x_4_);
return v_res_5_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___redArg(lean_object* v_t_6_, lean_object* v_k_7_){
_start:
{
if (lean_obj_tag(v_t_6_) == 0)
{
lean_object* v_side_8_; lean_object* v___x_9_; 
v_side_8_ = lean_ctor_get(v_t_6_, 0);
lean_inc(v_side_8_);
lean_dec_ref_known(v_t_6_, 1);
v___x_9_ = lean_apply_1(v_k_7_, v_side_8_);
return v___x_9_;
}
else
{
lean_object* v_w_10_; lean_object* v_h_11_; lean_object* v___x_12_; 
v_w_10_ = lean_ctor_get(v_t_6_, 0);
lean_inc(v_w_10_);
v_h_11_ = lean_ctor_get(v_t_6_, 1);
lean_inc(v_h_11_);
lean_dec_ref_known(v_t_6_, 2);
v___x_12_ = lean_apply_2(v_k_7_, v_w_10_, v_h_11_);
return v___x_12_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim(lean_object* v_motive_13_, lean_object* v_ctorIdx_14_, lean_object* v_t_15_, lean_object* v_h_16_, lean_object* v_k_17_){
_start:
{
lean_object* v___x_18_; 
v___x_18_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___redArg(v_t_15_, v_k_17_);
return v___x_18_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___boxed(lean_object* v_motive_19_, lean_object* v_ctorIdx_20_, lean_object* v_t_21_, lean_object* v_h_22_, lean_object* v_k_23_){
_start:
{
lean_object* v_res_24_; 
v_res_24_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim(v_motive_19_, v_ctorIdx_20_, v_t_21_, v_h_22_, v_k_23_);
lean_dec(v_ctorIdx_20_);
return v_res_24_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_square_elim___redArg(lean_object* v_t_25_, lean_object* v_square_26_){
_start:
{
lean_object* v___x_27_; 
v___x_27_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___redArg(v_t_25_, v_square_26_);
return v___x_27_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_square_elim(lean_object* v_motive_28_, lean_object* v_t_29_, lean_object* v_h_30_, lean_object* v_square_31_){
_start:
{
lean_object* v___x_32_; 
v___x_32_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___redArg(v_t_29_, v_square_31_);
return v___x_32_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_rect_elim___redArg(lean_object* v_t_33_, lean_object* v_rect_34_){
_start:
{
lean_object* v___x_35_; 
v___x_35_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___redArg(v_t_33_, v_rect_34_);
return v___x_35_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_rect_elim(lean_object* v_motive_36_, lean_object* v_t_37_, lean_object* v_h_38_, lean_object* v_rect_39_){
_start:
{
lean_object* v___x_40_; 
v___x_40_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_ctorElim___redArg(v_t_37_, v_rect_39_);
return v___x_40_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area(lean_object* v_x_41_){
_start:
{
if (lean_obj_tag(v_x_41_) == 0)
{
lean_object* v_side_42_; lean_object* v___x_43_; 
v_side_42_ = lean_ctor_get(v_x_41_, 0);
v___x_43_ = lean_nat_mul(v_side_42_, v_side_42_);
return v___x_43_;
}
else
{
lean_object* v_w_44_; lean_object* v_h_45_; lean_object* v___x_46_; 
v_w_44_ = lean_ctor_get(v_x_41_, 0);
v_h_45_ = lean_ctor_get(v_x_41_, 1);
v___x_46_ = lean_nat_mul(v_w_44_, v_h_45_);
return v___x_46_;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area___boxed(lean_object* v_x_47_){
_start:
{
lean_object* v_res_48_; 
v_res_48_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes_Shape_area(v_x_47_);
lean_dec_ref(v_x_47_);
return v_res_48_;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_step09_code_shapes(uint8_t builtin) {
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
