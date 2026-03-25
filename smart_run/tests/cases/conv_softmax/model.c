/* auto generate by HHB_VERSION 3.2.2 */

#include <csi_nn.h>
#include <shl_utils.h>

void *csinn_(char *params_base) {
  struct csinn_session *sess = csinn_alloc_session();
  sess->base_run_mode = CSINN_RM_CPU_GRAPH;
  sess->base_quant_type = CSINN_QUANT_INT8_ASYM;
  sess->model.save_mode = CSINN_RUN_ONLY;
  sess->base_api = CSINN_REF;
  sess->base_dtype = CSINN_DTYPE_INT8;
  sess->dynamic_shape = CSINN_FALSE;
  csinn_session_init(sess);
  csinn_set_input_number(1, sess);
  csinn_set_output_number(1, sess);

  struct csinn_tensor *input = csinn_alloc_tensor(sess);
  input->name = "input@@conv2d_/conv/Conv_1_fuse_bias_add_/conv/Conv_2_0";
  input->dtype = CSINN_DTYPE_INT8;
  input->layout = CSINN_LAYOUT_NCHW;
  input->dim[0] = 1;
  input->dim[1] = 16;
  input->dim[2] = 28;
  input->dim[3] = 28;
  input->dim_count = 4;
  memcpy(input->qinfo, params_base + 0, sizeof(struct csinn_quant_info) * 1);
  struct csinn_tensor *output_0 = csinn_alloc_tensor(sess);
  output_0->name = "output_0";
  output_0->dtype = CSINN_DTYPE_INT8;
  output_0->layout = CSINN_LAYOUT_NCHW;
  output_0->dim[0] = 1;
  output_0->dim[1] = 2;
  output_0->dim[2] = 26;
  output_0->dim[3] = 26;
  output_0->dim_count = 4;
  memcpy(output_0->qinfo, params_base + 40, sizeof(struct csinn_quant_info) * 1);
  struct csinn_tensor *kernel_0 = csinn_alloc_tensor(sess);
  kernel_0->name = "kernel_0";
  kernel_0->data = params_base + 120;
  kernel_0->is_const = 1;
  kernel_0->dtype = CSINN_DTYPE_INT8;
  kernel_0->layout = CSINN_LAYOUT_OIHW;
  kernel_0->dim[0] = 2;
  kernel_0->dim[1] = 16;
  kernel_0->dim[2] = 3;
  kernel_0->dim[3] = 3;
  kernel_0->dim_count = 4;
  memcpy(kernel_0->qinfo, params_base + 80, sizeof(struct csinn_quant_info) * 1);
  struct csinn_tensor *bias_0 = csinn_alloc_tensor(sess);
  bias_0->name = "bias_0";
  bias_0->data = params_base + 448;
  bias_0->is_const = 1;
  bias_0->dtype = CSINN_DTYPE_INT32;
  bias_0->layout = CSINN_LAYOUT_O;
  bias_0->dim[0] = 2;
  bias_0->dim_count = 1;
  memcpy(bias_0->qinfo, params_base + 408, sizeof(struct csinn_quant_info) * 1);
  struct csinn_conv2d_params *params_0 = csinn_alloc_params(sizeof(struct csinn_conv2d_params), sess);
  params_0->group = 1;
  params_0->stride_height = 1;
  params_0->stride_width = 1;
  params_0->dilation_height = 1;
  params_0->dilation_width = 1;
  params_0->conv_extra.kernel_tm = NULL;
  params_0->conv_extra.conv_mode = CSINN_DIRECT;
  params_0->pad_top = 0;
  params_0->pad_left = 0;
  params_0->pad_down = 0;
  params_0->pad_right = 0;
  params_0->base.name = "conv2d_/conv/Conv_1_fuse_bias_add_/conv/Conv_2";
  params_0->base.quant_type = CSINN_QUANT_INT8_ASYM;
  csinn_conv2d_init(input, output_0, kernel_0, bias_0, params_0);
  struct csinn_tensor *output_1 = csinn_alloc_tensor(sess);
  output_1->name = "softmax_output@@/softmax/Softmax_3_1";
  output_1->dtype = CSINN_DTYPE_INT8;
  output_1->layout = CSINN_LAYOUT_NCHW;
  output_1->dim[0] = 1;
  output_1->dim[1] = 2;
  output_1->dim[2] = 26;
  output_1->dim[3] = 26;
  output_1->dim_count = 4;
  memcpy(output_1->qinfo, params_base + 456, sizeof(struct csinn_quant_info) * 1);
  struct csinn_softmax_params *params_1 = csinn_alloc_params(sizeof(struct csinn_softmax_params), sess);
  params_1->axis = 1;
  params_1->base.name = "softmax_output@@/softmax/Softmax_3";
  params_1->base.quant_type = CSINN_QUANT_INT8_ASYM;
  csinn_softmax_init(output_0, output_1, params_1);
  csinn_set_tensor_entry(input, sess);
  csinn_set_input(0, input, sess);

  csinn_conv2d(input, output_0, kernel_0, bias_0, params_0);
  csinn_softmax(output_0, output_1, params_1);
  csinn_set_output(0, output_1, sess);

  csinn_session_setup(sess);
  return sess;
}
void csinn_update_input_and_run(struct csinn_tensor **input_tensors , void *sess) {
  csinn_update_input(0, input_tensors[0], sess);
  csinn_session_run(sess);
}
