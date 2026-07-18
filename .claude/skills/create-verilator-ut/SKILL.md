---
name: create-verilator-ut
description: Write verilator unit test for a given Verilog module.
---

1. The unit test should be created under the `verif/tb` directory.
2. One unit test sits in a subfolder under `verif/tb` directory. One Makefile and one or multiple testbench cpp is created for one unit test.
3. The Verilog code is compiled into C++ using Verilator for testing.
4. The user should give a `tc_spec` file to specify the test cases. It contains a `Common` session describing the common parameters for the test cases, and also contains a `TestCases` session describing each test case. 
5. Each test case in `TestCases` session should have a description, input operands, and expected result.
6. If the expected reulst says you should compare with c-model result, check if c-model is already presented in `verif/model` directory, if not, you should write a c-model for the DUT. 
7. When constructing c-model, you should not look at the RTL implementation. Instead, look at the interface of your DUT to think about how to implement the c-model from the software and algorithm point of view. If there are any part unclear, discuss with the user. You should always output a brief plan to the user on how you write the c-model, to be prove or further updated by the user. 
8. Print the RTL C++ output with the testbench cpp's output, and compute their difference in decimal. For example, if the RTL output is FP32, you should convert the RTL output to decimal, and also convert the c-model output to decimal, then compute their difference. 
9. If the difference is larger than 10^-3, report it as a failure, else report it as a pass.
10. count how many test cases are passed and how many test cases are failed, and report the summary to the user. 
11. Always run the test once to see if the flow is working correctly, but you should not debug if the test is failed until the user explicitly ask you to do so. 
 