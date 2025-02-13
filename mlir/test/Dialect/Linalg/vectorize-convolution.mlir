// RUN: mlir-opt -split-input-file -test-linalg-transform-patterns=test-linalg-to-vector-patterns %s | FileCheck %s

func.func @conv1d_nwc_4x2x8_memref(%input: memref<4x6x3xf32>, %filter: memref<1x3x8xf32>, %output: memref<4x2x8xf32>) {
  linalg.conv_1d_nwc_wcf
    {dilations = dense<1> : tensor<1xi64>, strides = dense<3> : tensor<1xi64>}
    ins(%input, %filter : memref<4x6x3xf32>, memref<1x3x8xf32>)
    outs(%output : memref<4x2x8xf32>)
  return
}

// CHECK: #[[INPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK: #[[FILTER_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
// CHECK: #[[OUTPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>

//      CHECK: func @conv1d_nwc_4x2x8_memref
// CHECK-SAME: (%[[INPUT:.+]]: memref<4x6x3xf32>, %[[FILTER:.+]]: memref<1x3x8xf32>, %[[OUTPUT:.+]]: memref<4x2x8xf32>)

//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//  CHECK-DAG:   %[[V_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 3, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x1x3xf32>

//      CHECK:    %[[V_FILTER:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<1x3x8xf32>

//      CHECK:  %[[V_OUTPUT_0:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>
//      CHECK:  %[[V_OUTPUT_1:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 1, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[CONTRACT_0:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_0]], %[[V_FILTER]], %[[V_OUTPUT_0]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>

/// w == 1, kw == 0
//      CHECK:   %[[CONTRACT_1:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_1]], %[[V_FILTER]], %[[V_OUTPUT_1]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[RES_0:.+]] = vector.insert_strided_slice %[[CONTRACT_0]], %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>
/// w == 1, kw == 0
//      CHECK:   %[[RES_1:.+]] = vector.insert_strided_slice %[[CONTRACT_1]], %[[RES_0]]
// CHECK-SAME:     {offsets = [0, 1, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[RES_1]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

// -----

// The i8i8i32 case is similar to f32 case, so checking one case is enough for
// test coverage.
func.func @conv1d_nwc_4x2x8_i8i8i32_memref(%input: memref<4x6x3xi8>, %filter: memref<1x3x8xi8>, %output: memref<4x2x8xi32>) {
  linalg.conv_1d_nwc_wcf
    {dilations = dense<1> : tensor<1xi64>, strides = dense<3> : tensor<1xi64>}
    ins(%input, %filter : memref<4x6x3xi8>, memref<1x3x8xi8>)
    outs(%output : memref<4x2x8xi32>)
  return
}

// CHECK: #[[INPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK: #[[FILTER_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
// CHECK: #[[OUTPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>

//      CHECK: func @conv1d_nwc_4x2x8_i8i8i32_memref
// CHECK-SAME: (%[[INPUT:.+]]: memref<4x6x3xi8>, %[[FILTER:.+]]: memref<1x3x8xi8>, %[[OUTPUT:.+]]: memref<4x2x8xi32>)

//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[C0_I8:.+]] = arith.constant 0 : i8
//  CHECK-DAG:   %[[C0_I32:.+]] = arith.constant 0 : i32

/// Read the whole data in one shot.
//  CHECK-DAG:   %[[V_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[C0_I8]]
//  CHECK-DAG:  %[[V_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]], %[[C0_I8]]
//  CHECK-DAG:  %[[V_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[C0_I32]]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xi8> to vector<4x1x3xi8>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 3, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xi8> to vector<4x1x3xi8>

//      CHECK:    %[[V_FILTER:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<1x3x8xi8>

//      CHECK:  %[[V_OUTPUT_0:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xi32> to vector<4x1x8xi32>
//      CHECK:  %[[V_OUTPUT_1:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 1, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xi32> to vector<4x1x8xi32>

/// w == 0, kw == 0
//      CHECK:   %[[CONTRACT_0:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_0]], %[[V_FILTER]], %[[V_OUTPUT_0]]
// CHECK-SAME:     : vector<4x1x3xi8>, vector<3x8xi8> into vector<4x1x8xi32>

/// w == 1, kw == 0
//      CHECK:   %[[CONTRACT_1:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_1]], %[[V_FILTER]], %[[V_OUTPUT_1]]
// CHECK-SAME:     : vector<4x1x3xi8>, vector<3x8xi8> into vector<4x1x8xi32>

/// w == 0, kw == 0
//      CHECK:   %[[RES_0:.+]] = vector.insert_strided_slice %[[CONTRACT_0]], %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], strides = [1, 1, 1]} : vector<4x1x8xi32> into vector<4x2x8xi32>
/// w == 1, kw == 0
//      CHECK:   %[[RES_1:.+]] = vector.insert_strided_slice %[[CONTRACT_1]], %[[RES_0]]
// CHECK-SAME:     {offsets = [0, 1, 0], strides = [1, 1, 1]} : vector<4x1x8xi32> into vector<4x2x8xi32>

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[RES_1]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

// -----

func.func @conv1d_nwc_4x2x8_memref(%input: memref<4x6x3xf32>, %filter: memref<2x3x8xf32>, %output: memref<4x2x8xf32>) {
  linalg.conv_1d_nwc_wcf
    {dilations = dense<2> : tensor<1xi64>, strides = dense<3> : tensor<1xi64>}
    ins(%input, %filter : memref<4x6x3xf32>, memref<2x3x8xf32>)
    outs(%output : memref<4x2x8xf32>)
  return
}

// CHECK: #[[INPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK: #[[FILTER_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
// CHECK: #[[OUTPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>

//      CHECK: func @conv1d_nwc_4x2x8_memref
// CHECK-SAME: (%[[INPUT:.+]]: memref<4x6x3xf32>, %[[FILTER:.+]]: memref<2x3x8xf32>, %[[OUTPUT:.+]]: memref<4x2x8xf32>)

//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//  CHECK-DAG:   %[[V_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:   %[[V_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:   %[[V_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 3, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_2:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 2, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_3:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 5, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>

//      CHECK:  %[[V_FILTER_0:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<2x3x8xf32>
//      CHECK:  %[[V_FILTER_1:.+]] = vector.extract %[[V_FILTER_R]][1] : vector<2x3x8xf32>

//      CHECK:  %[[V_OUTPUT_0:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>
//      CHECK:  %[[V_OUTPUT_1:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 1, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[CONTRACT_0:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_0]], %[[V_FILTER_0]], %[[V_OUTPUT_0]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
/// w == 1, kw == 0
//      CHECK:   %[[CONTRACT_1:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_1]], %[[V_FILTER_0]], %[[V_OUTPUT_1]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
/// w == 1, kw == 1
//      CHECK:   %[[CONTRACT_2:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_2]], %[[V_FILTER_1]], %[[CONTRACT_0]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
/// w == 1, kw == 1
//      CHECK:   %[[CONTRACT_3:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_3]], %[[V_FILTER_1]], %[[CONTRACT_1]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[RES_0:.+]] = vector.insert_strided_slice %[[CONTRACT_2]], %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>
/// w == 1, kw == 0
//      CHECK:   %[[RES_1:.+]] = vector.insert_strided_slice %[[CONTRACT_3]], %[[RES_0]]
// CHECK-SAME:     {offsets = [0, 1, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[RES_1]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

// -----

func.func @conv1d_nwc_4x2x8_memref(%input: memref<4x6x3xf32>, %filter: memref<2x3x8xf32>, %output: memref<4x2x8xf32>) {
  linalg.conv_1d_nwc_wcf
    {dilations = dense<2> : tensor<1xi64>, strides = dense<1> : tensor<1xi64>}
    ins(%input, %filter : memref<4x6x3xf32>, memref<2x3x8xf32>)
    outs(%output : memref<4x2x8xf32>)
  return
}

// CHECK: #[[INPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK: #[[FILTER_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
// CHECK: #[[OUTPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>

//      CHECK: func @conv1d_nwc_4x2x8_memref
// CHECK-SAME: (%[[INPUT:.+]]: memref<4x6x3xf32>, %[[FILTER:.+]]: memref<2x3x8xf32>, %[[OUTPUT:.+]]: memref<4x2x8xf32>)

//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//  CHECK-DAG:   %[[V_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 2, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x2x3xf32>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 2, 0], sizes = [4, 2, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x2x3xf32>

//      CHECK:  %[[V_FILTER_0:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<2x3x8xf32>
//      CHECK:  %[[V_FILTER_1:.+]] = vector.extract %[[V_FILTER_R]][1] : vector<2x3x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[CONTRACT_0:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_0]], %[[V_FILTER_0]], %[[V_OUTPUT_R]]
// CHECK-SAME:     : vector<4x2x3xf32>, vector<3x8xf32> into vector<4x2x8xf32>
/// w == 0, kw == 1
//      CHECK:   %[[CONTRACT_1:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_1]], %[[V_FILTER_1]], %[[CONTRACT_0]]
// CHECK-SAME:     : vector<4x2x3xf32>, vector<3x8xf32> into vector<4x2x8xf32>

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[CONTRACT_1]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

// -----

func.func @conv1d_ncw_4x8x2_memref(%input: memref<4x3x6xf32>, %filter: memref<8x3x1xf32>, %output: memref<4x8x2xf32>) {
  linalg.conv_1d_ncw_fcw
    {dilations = dense<1> : tensor<1xi64>, strides = dense<3> : tensor<1xi64>}
    ins(%input, %filter : memref<4x3x6xf32>, memref<8x3x1xf32>)
    outs(%output : memref<4x8x2xf32>)
  return
}

// CHECK: #[[INPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK: #[[FILTER_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
// CHECK: #[[OUTPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>

//      CHECK: func @conv1d_ncw_4x8x2_memref
// CHECK-SAME: (%[[INPUT:.+]]: memref<4x3x6xf32>, %[[FILTER:.+]]: memref<8x3x1xf32>, %[[OUTPUT:.+]]: memref<4x8x2xf32>)

//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//  CHECK-DAG:   %[[V_NWC_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_NWC_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_NWC_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]

/// Transpose result to nwc format.
//  CHECK-DAG:   %[[V_INPUT_R:.+]] = vector.transpose %[[V_NWC_INPUT_R]], [0, 2, 1]
//  CHECK-DAG:  %[[V_FILTER_R:.+]] = vector.transpose %[[V_NWC_FILTER_R]], [2, 1, 0]
//  CHECK-DAG:  %[[V_OUTPUT_R:.+]] = vector.transpose %[[V_NWC_OUTPUT_R]], [0, 2, 1]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 3, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x1x3xf32>

//      CHECK:    %[[V_FILTER:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<1x3x8xf32>

//      CHECK:  %[[V_OUTPUT_0:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>
//      CHECK:  %[[V_OUTPUT_1:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 1, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[CONTRACT_0:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_0]], %[[V_FILTER]], %[[V_OUTPUT_0]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>

/// w == 1, kw == 0
//      CHECK:   %[[CONTRACT_1:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_1]], %[[V_FILTER]], %[[V_OUTPUT_1]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[RES_0:.+]] = vector.insert_strided_slice %[[CONTRACT_0]], %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>
/// w == 1, kw == 0
//      CHECK:   %[[RES_1:.+]] = vector.insert_strided_slice %[[CONTRACT_1]], %[[RES_0]]
// CHECK-SAME:     {offsets = [0, 1, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>

/// Transpose result to ncw format.
//  CHECK:  %[[RES_2:.+]] = vector.transpose %[[RES_1]], [0, 2, 1]

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[RES_2]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

// -----

func.func @conv1d_ncw_4x8x2_memref(%input: memref<4x3x6xf32>, %filter: memref<8x3x2xf32>, %output: memref<4x8x2xf32>) {
  linalg.conv_1d_ncw_fcw
    {dilations = dense<2> : tensor<1xi64>, strides = dense<3> : tensor<1xi64>}
    ins(%input, %filter : memref<4x3x6xf32>, memref<8x3x2xf32>)
    outs(%output : memref<4x8x2xf32>)
  return
}

// CHECK: #[[INPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK: #[[FILTER_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
// CHECK: #[[OUTPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>

//      CHECK: func @conv1d_ncw_4x8x2_memref
// CHECK-SAME: (%[[INPUT:.+]]: memref<4x3x6xf32>, %[[FILTER:.+]]: memref<8x3x2xf32>, %[[OUTPUT:.+]]: memref<4x8x2xf32>)

//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//  CHECK-DAG:   %[[V_NWC_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:   %[[V_NWC_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:   %[[V_NWC_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]

/// Transpose result to nwc format.
//  CHECK-DAG:   %[[V_INPUT_R:.+]] = vector.transpose %[[V_NWC_INPUT_R]], [0, 2, 1]
//  CHECK-DAG:  %[[V_FILTER_R:.+]] = vector.transpose %[[V_NWC_FILTER_R]], [2, 1, 0]
//  CHECK-DAG:  %[[V_OUTPUT_R:.+]] = vector.transpose %[[V_NWC_OUTPUT_R]], [0, 2, 1]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 3, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_2:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 2, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>
//      CHECK:   %[[V_INPUT_3:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 5, 0], sizes = [4, 1, 3], strides = [1, 1, 1]} : vector<4x6x3xf32> to vector<4x1x3xf32>

//      CHECK:  %[[V_FILTER_0:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<2x3x8xf32>
//      CHECK:  %[[V_FILTER_1:.+]] = vector.extract %[[V_FILTER_R]][1] : vector<2x3x8xf32>

//      CHECK:  %[[V_OUTPUT_0:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>
//      CHECK:  %[[V_OUTPUT_1:.+]] = vector.extract_strided_slice %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 1, 0], sizes = [4, 1, 8], strides = [1, 1, 1]} : vector<4x2x8xf32> to vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[CONTRACT_0:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_0]], %[[V_FILTER_0]], %[[V_OUTPUT_0]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
/// w == 1, kw == 0
//      CHECK:   %[[CONTRACT_1:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_1]], %[[V_FILTER_0]], %[[V_OUTPUT_1]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
/// w == 1, kw == 1
//      CHECK:   %[[CONTRACT_2:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_2]], %[[V_FILTER_1]], %[[CONTRACT_0]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>
/// w == 1, kw == 1
//      CHECK:   %[[CONTRACT_3:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_3]], %[[V_FILTER_1]], %[[CONTRACT_1]]
// CHECK-SAME:     : vector<4x1x3xf32>, vector<3x8xf32> into vector<4x1x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[RES_0:.+]] = vector.insert_strided_slice %[[CONTRACT_2]], %[[V_OUTPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>
/// w == 1, kw == 0
//      CHECK:   %[[RES_1:.+]] = vector.insert_strided_slice %[[CONTRACT_3]], %[[RES_0]]
// CHECK-SAME:     {offsets = [0, 1, 0], strides = [1, 1, 1]} : vector<4x1x8xf32> into vector<4x2x8xf32>

/// Transpose result to ncw format.
//  CHECK:  %[[RES_2:.+]] = vector.transpose %[[RES_1]], [0, 2, 1]

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[RES_2]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

// -----

func.func @conv1d_ncw_4x8x2_memref(%input: memref<4x3x6xf32>, %filter: memref<8x3x2xf32>, %output: memref<4x8x2xf32>) {
  linalg.conv_1d_ncw_fcw
    {dilations = dense<2> : tensor<1xi64>, strides = dense<1> : tensor<1xi64>}
    ins(%input, %filter : memref<4x3x6xf32>, memref<8x3x2xf32>)
    outs(%output : memref<4x8x2xf32>)
  return
}

// CHECK: #[[INPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK: #[[FILTER_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d3, d2)>
// CHECK: #[[OUTPUT_MAP:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d2)>

//      CHECK: func @conv1d_ncw_4x8x2_memref
// CHECK-SAME: (%[[INPUT:.+]]: memref<4x3x6xf32>, %[[FILTER:.+]]: memref<8x3x2xf32>, %[[OUTPUT:.+]]: memref<4x8x2xf32>)

//  CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//  CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//  CHECK-DAG:   %[[V_NWC_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_NWC_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]
//  CHECK-DAG:  %[[V_NWC_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]], %[[F0]]

/// Transpose result to nwc format.
//  CHECK-DAG:   %[[V_INPUT_R:.+]] = vector.transpose %[[V_NWC_INPUT_R]], [0, 2, 1]
//  CHECK-DAG:  %[[V_FILTER_R:.+]] = vector.transpose %[[V_NWC_FILTER_R]], [2, 1, 0]
//  CHECK-DAG:  %[[V_OUTPUT_R:.+]] = vector.transpose %[[V_NWC_OUTPUT_R]], [0, 2, 1]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [4, 2, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x2x3xf32>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 2, 0], sizes = [4, 2, 3], strides = [1, 1, 1]} : vector<4x4x3xf32> to vector<4x2x3xf32>

//      CHECK:  %[[V_FILTER_0:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<2x3x8xf32>
//      CHECK:  %[[V_FILTER_1:.+]] = vector.extract %[[V_FILTER_R]][1] : vector<2x3x8xf32>

/// w == 0, kw == 0
//      CHECK:   %[[CONTRACT_0:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_0]], %[[V_FILTER_0]], %[[V_OUTPUT_R]]
// CHECK-SAME:     : vector<4x2x3xf32>, vector<3x8xf32> into vector<4x2x8xf32>
/// w == 0, kw == 1
//      CHECK:   %[[CONTRACT_1:.+]] = vector.contract {
// CHECK-SAME:       indexing_maps = [#[[INPUT_MAP]], #[[FILTER_MAP]], #[[OUTPUT_MAP]]],
// CHECK-SAME:       iterator_types = ["parallel", "parallel", "parallel", "reduction"]
// CHECK-SAME:     %[[V_INPUT_1]], %[[V_FILTER_1]], %[[CONTRACT_0]]
// CHECK-SAME:     : vector<4x2x3xf32>, vector<3x8xf32> into vector<4x2x8xf32>

/// Transpose result to ncw format.
//  CHECK:  %[[RES:.+]] = vector.transpose %[[CONTRACT_1]], [0, 2, 1]

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[RES]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]


// -----

func.func @depthwise_conv1d_nwc_wc_3x5x4xf32_memref(%input: memref<3x5x4xf32>, %filter: memref<2x4xf32>, %output: memref<3x2x4xf32>) {
  linalg.depthwise_conv_1d_nwc_wc
    {dilations = dense<2> : tensor<1xi64>, strides = dense<1> : tensor<1xi64>}
    ins(%input, %filter : memref<3x5x4xf32>, memref<2x4xf32>)
    outs(%output : memref<3x2x4xf32>)
  return
}

//       CHECK: func @depthwise_conv1d_nwc_wc_3x5x4xf32_memref
//  CHECK-SAME:   (%[[INPUT:[0-9a-z]+]]: memref<3x5x4xf32>, %[[FILTER:[0-9a-z]+]]: memref<2x4xf32>, %[[OUTPUT:[0-9a-z]+]]: memref<3x2x4xf32>)

//   CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//   CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//      CHECK:   %[[V_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]]
//      CHECK:  %[[V_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]]]
//      CHECK:  %[[V_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [3, 2, 4], strides = [1, 1, 1]} : vector<3x4x4xf32> to vector<3x2x4xf32>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 2, 0], sizes = [3, 2, 4], strides = [1, 1, 1]} : vector<3x4x4xf32> to vector<3x2x4xf32>

//      CHECK:  %[[V_FILTER_0:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<2x4xf32>
//      CHECK:  %[[V_FILTER_1:.+]] = vector.extract %[[V_FILTER_R]][1] : vector<2x4xf32>

/// w == 0, kw = 0
//      CHECK:  %[[B_FILTER_0:.*]] = vector.broadcast %[[V_FILTER_0]] : vector<4xf32> to vector<3x2x4xf32>
//      CHECK:  %[[FMA_0:.*]] = vector.fma %[[V_INPUT_0]], %[[B_FILTER_0]], %[[V_OUTPUT_R]] : vector<3x2x4xf32>

/// w == 0, kw = 1
//      CHECK:  %[[B_FILTER_1:.*]] = vector.broadcast %[[V_FILTER_1]] : vector<4xf32> to vector<3x2x4xf32>
//      CHECK:  %[[FMA_1:.*]] = vector.fma %[[V_INPUT_1]], %[[B_FILTER_1]], %[[FMA_0]] : vector<3x2x4xf32>

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[FMA_1]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]


// -----

func.func @depthwise_conv1d_nwc_wc_3x5x4xi8_memref(%input: memref<3x5x4xi8>, %filter: memref<2x4xi8>, %output: memref<3x2x4xi32>) {
  linalg.depthwise_conv_1d_nwc_wc
    {dilations = dense<2> : tensor<1xi64>, strides = dense<1> : tensor<1xi64>}
    ins(%input, %filter : memref<3x5x4xi8>, memref<2x4xi8>)
    outs(%output : memref<3x2x4xi32>)
  return
}

//       CHECK: func @depthwise_conv1d_nwc_wc_3x5x4xi8_memref
//  CHECK-SAME:   (%[[INPUT:[0-9a-z]+]]: memref<3x5x4xi8>, %[[FILTER:[0-9a-z]+]]: memref<2x4xi8>, %[[OUTPUT:[0-9a-z]+]]: memref<3x2x4xi32>)

//   CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index

/// Read the whole data in one shot.
//      CHECK:   %[[V_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]]
//      CHECK:  %[[V_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]]]
//      CHECK:  %[[V_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

//      CHECK:   %[[V_INPUT_0:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 0, 0], sizes = [3, 2, 4], strides = [1, 1, 1]} : vector<3x4x4xi8> to vector<3x2x4xi8>
//      CHECK:   %[[V_INPUT_1:.+]] = vector.extract_strided_slice %[[V_INPUT_R]]
// CHECK-SAME:     {offsets = [0, 2, 0], sizes = [3, 2, 4], strides = [1, 1, 1]} : vector<3x4x4xi8> to vector<3x2x4xi8>

//      CHECK:  %[[V_FILTER_0:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<2x4xi8>
//      CHECK:  %[[V_FILTER_1:.+]] = vector.extract %[[V_FILTER_R]][1] : vector<2x4xi8>

/// w == 0, kw = 
//      CHECK:  %[[EXT_INPUT_0:.*]] = arith.extsi %[[V_INPUT_0]] : vector<3x2x4xi8> to vector<3x2x4xi32>
//      CHECK:  %[[B_FILTER_0:.*]] = vector.broadcast %[[V_FILTER_0]] : vector<4xi8> to vector<3x2x4xi8>
//      CHECK:  %[[EXT_FILTER_0:.*]] = arith.extsi %[[B_FILTER_0]] : vector<3x2x4xi8> to vector<3x2x4xi32>
//      CHECK:  %[[MUL_0:.*]] = arith.muli %[[EXT_INPUT_0]], %[[EXT_FILTER_0]] : vector<3x2x4xi32>
//      CHECK:  %[[ADD_0:.*]] = arith.addi %[[MUL_0]], %[[V_OUTPUT_R]] : vector<3x2x4xi32>

/// w == 0, kw = 1
//      CHECK:  %[[EXT_INPUT_1:.*]] = arith.extsi %[[V_INPUT_1]] : vector<3x2x4xi8> to vector<3x2x4xi32>
//      CHECK:  %[[B_FILTER_1:.*]] = vector.broadcast %[[V_FILTER_1]] : vector<4xi8> to vector<3x2x4xi8>
//      CHECK:  %[[EXT_FILTER_1:.*]] = arith.extsi %[[B_FILTER_1]] : vector<3x2x4xi8> to vector<3x2x4xi32>
//      CHECK:  %[[MUL_1:.*]] = arith.muli %[[EXT_INPUT_1]], %[[EXT_FILTER_1]] : vector<3x2x4xi32>
//      CHECK:  %[[ADD_1:.*]] = arith.addi %[[MUL_1]], %[[ADD_0]] : vector<3x2x4xi32>

// Write the result back in one shot.
//      CHECK:   vector.transfer_write %[[ADD_1]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]

// -----

func.func @conv_1d_nwc_wcf_mixed_type_memref(%input: memref<1x2x3xf16>, %filter: memref<1x3x2xf16>, %output: memref<1x2x2xf32>) {
  linalg.conv_1d_nwc_wcf
  {dilations = dense<1> : vector<1xi64>, strides = dense<1> : vector<1xi64>}
   ins(%input, %filter : memref<1x2x3xf16>, memref<1x3x2xf16>)
   outs(%output : memref<1x2x2xf32>)
  return
}

//       CHECK: func @conv_1d_nwc_wcf_mixed_type_memref
//  CHECK-SAME:   (%[[INPUT:[0-9a-z]+]]: memref<1x2x3xf16>, %[[FILTER:[0-9a-z]+]]: memref<1x3x2xf16>, %[[OUTPUT:[0-9a-z]+]]: memref<1x2x2xf32>)

//   CHECK-DAG:   %[[C0:.+]] = arith.constant 0 : index
//   CHECK-DAG:   %[[F0:.+]] = arith.constant 0.000000e+00 : f32

/// Read the whole data in one shot.
//      CHECK:   %[[V_INPUT_R:.+]] = vector.transfer_read %[[INPUT]][%[[C0]], %[[C0]], %[[C0]]]
//      CHECK:   %[[V_FILTER_R:.+]] = vector.transfer_read %[[FILTER]][%[[C0]], %[[C0]], %[[C0]]]
//      CHECK:   %[[V_OUTPUT_R:.+]] = vector.transfer_read %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]
//      CHECK:   %[[V_FILTER_1:.+]] = vector.extract %[[V_FILTER_R]][0] : vector<1x3x2xf16>
//      CHECK:   %[[CONT:.*]] = vector.contract
//        {{.*}} %[[V_INPUT_R]], %[[V_FILTER_1]], %[[V_OUTPUT_R]] : vector<1x2x3xf16>, vector<3x2xf16> into vector<1x2x2xf32>
//      CHECK:   vector.transfer_write %[[CONT]], %[[OUTPUT]][%[[C0]], %[[C0]], %[[C0]]]
