//
//  BNNS.swift
//  bnns
//
//  Created by 杨培文 on 16/9/17.
//  Copyright © 2016年 杨培文. All rights reserved.
//

import UIKit
import Accelerate

class BNNS {
    enum LayerType {
        case Dense
        case Convolution
        case Pooling
    }
    
    struct Layer{
        var layerType:LayerType
        var activationFunction:BNNSActivationFunction
        var inputSize:Int
        var outputSize:Int
    }
    
    var layers:[Layer] = []
    var filters:[BNNSFilter] = []
    var dataType:BNNSDataType = BNNSDataTypeFloat32;
    
    func createFullyConnectedLayer(inputSize: Int, outputSize: Int, activationFunction: BNNSActivationFunction, weights:[Float32], bias: [Float32]){
        var in_vec = BNNSVectorDescriptor(size: inputSize, data_type: dataType, data_scale: 0, data_bias: 0)
        var out_vec = BNNSVectorDescriptor(size: outputSize, data_type: dataType, data_scale: 0, data_bias: 0)
        let activation = BNNSActivation(function: activationFunction, alpha: 0, beta: 0)
        let weightsdata = BNNSLayerData(data: weights, data_type: dataType, data_scale: 1, data_bias: 0, data_table: nil)
        let biasdata = BNNSLayerData(data: bias, data_type: dataType, data_scale: 1, data_bias: 0, data_table: nil)
        var full = BNNSFullyConnectedLayerParameters(in_size: inputSize, out_size: outputSize, weights: weightsdata, bias: biasdata, activation: activation)
        let layer = Layer(layerType: .Dense, activationFunction: activationFunction, inputSize: inputSize, outputSize: outputSize)
        if let filter = BNNSFilterCreateFullyConnectedLayer(&in_vec, &out_vec, &full, nil){
            layers.append(layer)
            filters.append(filter)
        }
    }
    
    func forward(input:[Float32]) -> [Float32]{
        var iinput = input
        var output:[Float32] = []
        for (filter, layer) in zip(filters, layers){
            output =  [Float32](repeating:0, count:layer.outputSize)
            switch layer.layerType {
            case .Dense:
                BNNSFilterApply(filter, iinput, &output)
            default : break
            }
            iinput = output
        }
        return output
    }

}
