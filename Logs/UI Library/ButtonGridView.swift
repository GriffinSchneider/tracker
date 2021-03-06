//
//  ButtonGridView.swift
//  tracker
//
//  Created by Griffin on 10/16/16.
//  Copyright © 2016 griff.zone. All rights reserved.
//

import Foundation
import RxSwift
import RxGesture
import DRYUI

private let PADDING: CGFloat = 10

protocol GridViewButtonData: Hashable {
    var keepSmall: Bool { get }
}

class ButtonGridView<ButtonDataType: GridViewButtonData>: UIView {
    
    let buttons = Variable<[[ButtonDataType]]>([])
    let selection: Observable<(UIButton, ButtonDataType)>
    let longPress: Observable<(UIButton, ButtonDataType)>

    private let configBlock: (UIButton, ButtonDataType) -> Void
    private var _selection: Variable<(UIButton, ButtonDataType)?> = Variable(nil)
    private var _longPress: Variable<(UIButton, ButtonDataType)?> = Variable(nil)
    private let disposeBag: DisposeBag
    private var outputDisposable: Disposable? = nil
    private var buttonMap: [ButtonDataType: UIButton] = [:]
    private var sizeCache: [UIButton: (String?, CGSize)] = [:]
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    init(config: @escaping (UIButton, ButtonDataType) -> Void) {
        disposeBag = DisposeBag()
        selection = _selection.asObservable().filter { $0 != nil }.map { $0! }
        longPress = _longPress.asObservable().filter { $0 != nil }.map { $0! }
        configBlock = config
        super.init(frame: .zero)
        buttons.asObservable().subscribe(onNext: {[weak self] data in
            self?.display(inputData: data)
        }).disposed(by: disposeBag)
        
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(configureButtons), userInfo: nil, repeats: true)
    }
    
    private func display(inputData: [[ButtonDataType]]) {
        outputDisposable?.dispose()
        var foundMap = buttonMap
        
        // Add new buttons that aren't already in the map
        for data in inputData.joined() {
            if let found = foundMap.removeValue(forKey: data) {
                // If there was already a button in the map, then replace its key
                // with the new data, since it might be different even if it's 'equal'
                // to the old data
                buttonMap.removeValue(forKey: data)
                buttonMap[data] = found
            } else {
                self.addSubview(UIButton.self, { v in
                    v.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                    self.buttonMap[data] = v
                })
            }
        }
        
        // Remove buttons in the map that aren't in the new data
        for (data, button) in foundMap {
            buttonMap.removeValue(forKey: data)
            sizeCache.removeValue(forKey: button)
            button.removeFromSuperview()
        }
        
        for (_, button) in buttonMap {
            let g = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(g:)))
            g.minimumPressDuration = 0.23
            button.addGestureRecognizer(g)
        }
        
        outputDisposable = Observable.from(buttonMap.map { k, v in
            v.rx.tap.asObservable().map { (v, k) }
        }).merge().bind(to: _selection)

        UIView.beginAnimations(nil, context: nil)
        layoutSubviews()
        UIView.commitAnimations()
    }
    
    @objc private func longPressed(g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        for (data, button) in buttonMap {
            if g.view == button {
                _longPress.value = (button, data)
                return
            }
        }
    }

    @objc private func configureButtons() {
        for section in self.buttons.value {
            for data in section {
                let v = self.buttonMap[data]!
                self.configBlock(v, data)
            }
        }
    }

    private var lines = [[(ButtonDataType, UIButton)]]()
    override func layoutSubviews() {
        var lastButton: UIButton? = nil
        var isNewSection = false
        lines.removeAll()
        lines.append([])
        
        for section in self.buttons.value {
            isNewSection = true
            for data in section {
                let v = self.buttonMap[data]!
                self.configBlock(v, data)
                
                if let cachedSize = sizeCache[v],
                    v.title(for: .normal) == cachedSize.0 {
                    v.frame.size = cachedSize.1
                } else {
                    v.sizeToFit()
                    v.frame.size.width = max(v.frame.size.width, 60)
                    sizeCache[v] = (v.title(for: .normal), v.frame.size)
                }
                
                if let lastButton = lastButton {
                    v.frame.origin.x = lastButton.frame.origin.x + lastButton.frame.size.width + PADDING
                    v.frame.origin.y =  lastButton.frame.origin.y
                    if isNewSection || v.frame.origin.x + v.frame.size.width > v.superview!.frame.size.width {
                        v.frame.origin.x = PADDING
                        v.frame.origin.y = lastButton.frame.origin.y + lastButton.frame.size.height + (isNewSection ? 20 : 10)
                        lines.append([(data, v)])
                    } else {
                        lines[lines.count-1].append((data, v))
                    }
                } else {
                    lines[lines.count-1].append((data, v))
                    v.frame.origin.x = PADDING
                    v.frame.origin.y = 20
                }
                
                lastButton = v
                isNewSection = false
            }
        }
        
        for line in lines {
            lastButton = nil
            let totalWidth = line.reduce(0) { $0 + $1.1.frame.size.width }
            let availableWidth = frame.size.width - PADDING*2
            let numPaddings = CGFloat(line.count - 1)
            let requiredTotalWidth = availableWidth - numPaddings*PADDING
            let additionalTotalWidth = requiredTotalWidth - totalWidth
            let numButtonsToSpreadAdditionalWidthBetween = line.lazy.filter({ !$0.0.keepSmall }).count
            let amountToGrowEach = additionalTotalWidth / CGFloat(numButtonsToSpreadAdditionalWidthBetween)
            guard  amountToGrowEach > 0 else { continue }
            for (data, button) in line {
                if !data.keepSmall { button.frame.size.width += amountToGrowEach }
                if let lastButton = lastButton {
                    button.frame.origin.x = lastButton.frame.origin.x + lastButton.frame.size.width + PADDING
                }
                lastButton = button
            }
        }

        buttonMap.forEach { $0.value.isHighlighted = $0.value.isHighlighted }
    }
}
