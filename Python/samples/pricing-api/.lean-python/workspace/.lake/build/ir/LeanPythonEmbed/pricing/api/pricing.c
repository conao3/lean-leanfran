// Lean compiler output
// Module: LeanPythonEmbed.pricing.api.pricing
// Imports: public import Init public meta import Init public import LeanPythonModels.pricing.models
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
lean_object* lean_nat_add(lean_object*, lean_object*);
lean_object* lean_nat_div(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorIdx(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_none_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_none_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_percent_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_percent_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_fixed_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_fixed_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_pricing_api_pricing_subtotal_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_pricing_api_pricing_subtotal_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_total(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_total___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_pricing_api_pricing_0__LeanPythonEmbed_pricing_api_pricing_total_match__1_splitter___redArg(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_pricing_api_pricing_0__LeanPythonEmbed_pricing_api_pricing_total_match__1_splitter(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorIdx(lean_object* v_x_1_){
_start:
{
switch(lean_obj_tag(v_x_1_))
{
case 0:
{
lean_object* v___x_2_; 
v___x_2_ = lean_unsigned_to_nat(0u);
return v___x_2_;
}
case 1:
{
lean_object* v___x_3_; 
v___x_3_ = lean_unsigned_to_nat(1u);
return v___x_3_;
}
default: 
{
lean_object* v___x_4_; 
v___x_4_ = lean_unsigned_to_nat(2u);
return v___x_4_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorIdx___boxed(lean_object* v_x_5_){
_start:
{
lean_object* v_res_6_; 
v_res_6_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorIdx(v_x_5_);
lean_dec(v_x_5_);
return v_res_6_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(lean_object* v_t_7_, lean_object* v_k_8_){
_start:
{
switch(lean_obj_tag(v_t_7_))
{
case 0:
{
return v_k_8_;
}
case 1:
{
lean_object* v_p_9_; lean_object* v___x_10_; 
v_p_9_ = lean_ctor_get(v_t_7_, 0);
lean_inc(v_p_9_);
lean_dec_ref_known(v_t_7_, 1);
v___x_10_ = lean_apply_2(v_k_8_, v_p_9_, lean_box(0));
return v___x_10_;
}
default: 
{
lean_object* v_amount_11_; lean_object* v___x_12_; 
v_amount_11_ = lean_ctor_get(v_t_7_, 0);
lean_inc(v_amount_11_);
lean_dec_ref_known(v_t_7_, 1);
v___x_12_ = lean_apply_1(v_k_8_, v_amount_11_);
return v___x_12_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim(lean_object* v_motive_13_, lean_object* v_ctorIdx_14_, lean_object* v_t_15_, lean_object* v_h_16_, lean_object* v_k_17_){
_start:
{
lean_object* v___x_18_; 
v___x_18_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(v_t_15_, v_k_17_);
return v___x_18_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___boxed(lean_object* v_motive_19_, lean_object* v_ctorIdx_20_, lean_object* v_t_21_, lean_object* v_h_22_, lean_object* v_k_23_){
_start:
{
lean_object* v_res_24_; 
v_res_24_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim(v_motive_19_, v_ctorIdx_20_, v_t_21_, v_h_22_, v_k_23_);
lean_dec(v_ctorIdx_20_);
return v_res_24_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_none_elim___redArg(lean_object* v_t_25_, lean_object* v_none_26_){
_start:
{
lean_object* v___x_27_; 
v___x_27_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(v_t_25_, v_none_26_);
return v___x_27_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_none_elim(lean_object* v_motive_28_, lean_object* v_t_29_, lean_object* v_h_30_, lean_object* v_none_31_){
_start:
{
lean_object* v___x_32_; 
v___x_32_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(v_t_29_, v_none_31_);
return v___x_32_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_percent_elim___redArg(lean_object* v_t_33_, lean_object* v_percent_34_){
_start:
{
lean_object* v___x_35_; 
v___x_35_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(v_t_33_, v_percent_34_);
return v___x_35_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_percent_elim(lean_object* v_motive_36_, lean_object* v_t_37_, lean_object* v_h_38_, lean_object* v_percent_39_){
_start:
{
lean_object* v___x_40_; 
v___x_40_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(v_t_37_, v_percent_39_);
return v___x_40_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_fixed_elim___redArg(lean_object* v_t_41_, lean_object* v_fixed_42_){
_start:
{
lean_object* v___x_43_; 
v___x_43_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(v_t_41_, v_fixed_42_);
return v___x_43_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_fixed_elim(lean_object* v_motive_44_, lean_object* v_t_45_, lean_object* v_h_46_, lean_object* v_fixed_47_){
_start:
{
lean_object* v___x_48_; 
v___x_48_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_Discount_ctorElim___redArg(v_t_45_, v_fixed_47_);
return v___x_48_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_pricing_api_pricing_subtotal_spec__0(lean_object* v_x_49_, lean_object* v_x_50_){
_start:
{
if (lean_obj_tag(v_x_50_) == 0)
{
return v_x_49_;
}
else
{
lean_object* v_head_51_; lean_object* v_tail_52_; lean_object* v_qty_53_; lean_object* v_unitPrice_54_; lean_object* v___x_55_; lean_object* v___x_56_; 
v_head_51_ = lean_ctor_get(v_x_50_, 0);
v_tail_52_ = lean_ctor_get(v_x_50_, 1);
v_qty_53_ = lean_ctor_get(v_head_51_, 1);
v_unitPrice_54_ = lean_ctor_get(v_head_51_, 2);
v___x_55_ = lean_nat_mul(v_qty_53_, v_unitPrice_54_);
v___x_56_ = lean_nat_add(v_x_49_, v___x_55_);
lean_dec(v___x_55_);
lean_dec(v_x_49_);
v_x_49_ = v___x_56_;
v_x_50_ = v_tail_52_;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_pricing_api_pricing_subtotal_spec__0___boxed(lean_object* v_x_58_, lean_object* v_x_59_){
_start:
{
lean_object* v_res_60_; 
v_res_60_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_pricing_api_pricing_subtotal_spec__0(v_x_58_, v_x_59_);
lean_dec(v_x_59_);
return v_res_60_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal(lean_object* v_items_61_){
_start:
{
lean_object* v___x_62_; lean_object* v___x_63_; 
v___x_62_ = lean_unsigned_to_nat(0u);
v___x_63_ = lp_lean_x2dpython_x2dworkspace_List_foldl___at___00LeanPythonEmbed_pricing_api_pricing_subtotal_spec__0(v___x_62_, v_items_61_);
return v___x_63_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal___boxed(lean_object* v_items_64_){
_start:
{
lean_object* v_res_65_; 
v_res_65_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal(v_items_64_);
lean_dec(v_items_64_);
return v_res_65_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_total(lean_object* v_items_66_, lean_object* v_d_67_){
_start:
{
switch(lean_obj_tag(v_d_67_))
{
case 0:
{
lean_object* v___x_68_; 
v___x_68_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal(v_items_66_);
return v___x_68_;
}
case 1:
{
lean_object* v_p_69_; lean_object* v___x_70_; lean_object* v___x_71_; lean_object* v___x_72_; lean_object* v___x_73_; lean_object* v___x_74_; 
v_p_69_ = lean_ctor_get(v_d_67_, 0);
v___x_70_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal(v_items_66_);
v___x_71_ = lean_nat_mul(v___x_70_, v_p_69_);
v___x_72_ = lean_unsigned_to_nat(100u);
v___x_73_ = lean_nat_div(v___x_71_, v___x_72_);
lean_dec(v___x_71_);
v___x_74_ = lean_nat_sub(v___x_70_, v___x_73_);
lean_dec(v___x_73_);
lean_dec(v___x_70_);
return v___x_74_;
}
default: 
{
lean_object* v_amount_75_; lean_object* v___x_76_; lean_object* v___x_77_; 
v_amount_75_ = lean_ctor_get(v_d_67_, 0);
v___x_76_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_subtotal(v_items_66_);
v___x_77_ = lean_nat_sub(v___x_76_, v_amount_75_);
lean_dec(v___x_76_);
return v___x_77_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_total___boxed(lean_object* v_items_78_, lean_object* v_d_79_){
_start:
{
lean_object* v_res_80_; 
v_res_80_ = lp_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing_total(v_items_78_, v_d_79_);
lean_dec(v_d_79_);
lean_dec(v_items_78_);
return v_res_80_;
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_pricing_api_pricing_0__LeanPythonEmbed_pricing_api_pricing_total_match__1_splitter___redArg(lean_object* v_d_81_, lean_object* v_h__1_82_, lean_object* v_h__2_83_, lean_object* v_h__3_84_){
_start:
{
switch(lean_obj_tag(v_d_81_))
{
case 0:
{
lean_object* v___x_85_; lean_object* v___x_86_; 
lean_dec(v_h__3_84_);
lean_dec(v_h__2_83_);
v___x_85_ = lean_box(0);
v___x_86_ = lean_apply_1(v_h__1_82_, v___x_85_);
return v___x_86_;
}
case 1:
{
lean_object* v_p_87_; lean_object* v___x_88_; 
lean_dec(v_h__3_84_);
lean_dec(v_h__1_82_);
v_p_87_ = lean_ctor_get(v_d_81_, 0);
lean_inc(v_p_87_);
lean_dec_ref_known(v_d_81_, 1);
v___x_88_ = lean_apply_2(v_h__2_83_, v_p_87_, lean_box(0));
return v___x_88_;
}
default: 
{
lean_object* v_amount_89_; lean_object* v___x_90_; 
lean_dec(v_h__2_83_);
lean_dec(v_h__1_82_);
v_amount_89_ = lean_ctor_get(v_d_81_, 0);
lean_inc(v_amount_89_);
lean_dec_ref_known(v_d_81_, 1);
v___x_90_ = lean_apply_1(v_h__3_84_, v_amount_89_);
return v___x_90_;
}
}
}
}
LEAN_EXPORT lean_object* lp_lean_x2dpython_x2dworkspace___private_LeanPythonEmbed_pricing_api_pricing_0__LeanPythonEmbed_pricing_api_pricing_total_match__1_splitter(lean_object* v_motive_91_, lean_object* v_d_92_, lean_object* v_h__1_93_, lean_object* v_h__2_94_, lean_object* v_h__3_95_){
_start:
{
switch(lean_obj_tag(v_d_92_))
{
case 0:
{
lean_object* v___x_96_; lean_object* v___x_97_; 
lean_dec(v_h__3_95_);
lean_dec(v_h__2_94_);
v___x_96_ = lean_box(0);
v___x_97_ = lean_apply_1(v_h__1_93_, v___x_96_);
return v___x_97_;
}
case 1:
{
lean_object* v_p_98_; lean_object* v___x_99_; 
lean_dec(v_h__3_95_);
lean_dec(v_h__1_93_);
v_p_98_ = lean_ctor_get(v_d_92_, 0);
lean_inc(v_p_98_);
lean_dec_ref_known(v_d_92_, 1);
v___x_99_ = lean_apply_2(v_h__2_94_, v_p_98_, lean_box(0));
return v___x_99_;
}
default: 
{
lean_object* v_amount_100_; lean_object* v___x_101_; 
lean_dec(v_h__2_94_);
lean_dec(v_h__1_93_);
v_amount_100_ = lean_ctor_get(v_d_92_, 0);
lean_inc(v_amount_100_);
lean_dec_ref_known(v_d_92_, 1);
v___x_101_ = lean_apply_1(v_h__3_95_, v_amount_100_);
return v___x_101_;
}
}
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonModels_pricing_models(uint8_t builtin);
void lean_initialize_runtime_module();
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_lean_x2dpython_x2dworkspace_LeanPythonEmbed_pricing_api_pricing(uint8_t builtin) {
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
res = initialize_lean_x2dpython_x2dworkspace_LeanPythonModels_pricing_models(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
