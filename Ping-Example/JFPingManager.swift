//
//  JFPingManager.swift
//  WindSpeedVPN
//
//  Created by zhoujianfeng on 2016/11/25.
//  Copyright © 2016年 zhoujianfeng. All rights reserved.
//

import UIKit

class JFPingManager: NSObject {
    
    /// 开始 批量ping 一批地址
    ///
    /// - Parameter addressList: ip地址列表
    /// - Returns: 线路速度
    @objc class func startPing(addressList: [String], finished: @escaping ([String : Double]?) -> ()) {
        
        if addressList.count == 0 {
            print("ip地址列表不能为空")
            return
        }
        
        // 存储所有ping值
        var pingResult = [String : [Double]]()
        for address in addressList {
            pingResult[address] = [Double]()
        }
        
        // 存储每个ping服务对象
        var pingServicesDict = [String : JFPingServices?]()
        
        // 需要移除的ping结果
        var needRemoveAddresses = [String]()
        
        // 创建任务组
        let group = DispatchGroup()
        let queue = DispatchQueue.main;
        
        for address in addressList {
            group.enter()
            queue.async {
                pingServicesDict[address] = JFPingServices.start(hostName: address, count: 4, pingCallback: { (pingItem) in
                    switch pingItem.status! {
                    case .didStart:
                        break
                    case .didFailToSendPacket:
                        needRemoveAddresses.append(pingItem.hostName!)
                    case .didReceivePacket:
                        pingResult[pingItem.hostName!]!.append(pingItem.timeMilliseconds!)
                    case .didReceiveUnexpectedPacket:
                        break
                    case .didTimeout:
                        // ping超时按1秒算
                        pingResult[pingItem.hostName!]!.append(1000.0)
                        group.leave()
                    case .didError:
                        needRemoveAddresses.append(pingItem.hostName!)
                        group.leave()
                    case .didFinished:
                        //                    print(pingItem.hostName! + " 完成")
                        pingServicesDict[pingItem.hostName!] = nil
                        group.leave()
                    }
                })
            }
        }
        
        //存储所有 ip ping 的平均值
        var pingAvgResult = [String : Double]();
        
        // 任务执行完毕再计算平均ping值
        group.notify(queue: DispatchQueue.main) { () -> Void in
            //            print("计算延迟")
            
            // 如果ping数据一个正常的都没有直接移除
            for (key, value) in pingResult {
                if !needRemoveAddresses.contains(key) && value.count == 0 {
                    needRemoveAddresses.append(key)
                }
            }
            
            // 移除非正常ping结果
            for address in needRemoveAddresses {
                print("⚠️ 移除ping失败的ip: \(address)")
                pingResult.remove(at: pingResult.index(forKey: address)!)
            }
            
            // 已经没有ip了
            if pingResult.count == 0 {
                finished(nil)
                return
            }
            
            
            // 计算所有 ip ping 的平均值
            for ping in pingResult {
                
                var sum = 0.0
                for value in ping.value {
                    sum += value
                }
                let avg = sum / Double(ping.value.count)
                
                //                print(ping.key + " 平均延迟:\(String(format: "%.2lfms", avg))")
                pingAvgResult[ping.key] = avg;
            }
            
            
            // 通知调用者,已经有数据
            finished(pingAvgResult);
        }
        
    }
}

