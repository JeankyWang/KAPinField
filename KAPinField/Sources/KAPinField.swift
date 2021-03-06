//
//  KAPinField.swift
//  KAPinCode
//
//  Created by Alexis Creuzot on 15/10/2018.
//  Copyright © 2018 alexiscreuzot. All rights reserved.
//

import UIKit

// Mark: - KAPinFieldDelegate
public protocol KAPinFieldDelegate : AnyObject {
    func pinField(_ field: KAPinField, didFinishWith code: String)
}

public struct KAPinFieldProperties {
    public weak var delegate : KAPinFieldDelegate? = nil
    public var numberOfCharacters: Int = 4 {
        didSet {
            precondition(numberOfCharacters >= 1, "Number of character must be >= 1")
        }
    }
    public var validCharacters: String = "0123456789" {
        didSet {
            precondition(validCharacters.count > 0, "There must be at least 1 valid character")
            precondition(!validCharacters.contains(token), "Valid characters can't contain token \"\(token)\"")
        }
    }
    public var token: Character = "•" {
        didSet {
            precondition(!validCharacters.contains(token), "Valid characters can't contain token \"\(token)\"")
            
            // Change space to insecable space
            if token == " " {
                self.token = " "
            }
        }
    }
}

public struct KAPinFieldAppearance {
    public var font : KA_MonospacedFont? = .menlo(40)
    public var tokenColor : UIColor?
    public var tokenFocusColor : UIColor?
    public var textColor : UIColor?
    public var kerning : CGFloat = 20.0
    public var backColor : UIColor = UIColor.clear
    public var backBorderColor : UIColor = UIColor.clear
    public var backBorderWidth : CGFloat = 1
    public var backCornerRadius : CGFloat = 4
    public var backOffset : CGFloat = 4
    public var backFocusColor : UIColor?
    public var backBorderFocusColor : UIColor?
    public var backActiveColor : UIColor?
    public var backBorderActiveColor : UIColor?
}

// Mark: - KAPinField Class
public class KAPinField : UITextField {
    
    // Mark: - Public vars
    public var properties = KAPinFieldProperties() {
        didSet {
            self.reload()
        }
    }
    public var appearance = KAPinFieldAppearance() {
        didSet {
            self.reloadAppearance()
        }
    }

    // Mark: - Overriden vars
    public override var text : String? {
        get { return invisibleText }
        set {
            self.invisibleField.text = newValue
        }
    }

    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(paste(_:)) // Only allow pasting
    }
    
    // Mark: - Private vars
    
    private var isRightToLeft : Bool {
        return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
    }
    
    // Uses an invisible UITextField to handle text
    // this is necessary for iOS12 .oneTimePassword feature
    private var invisibleField = UITextField()
    private var invisibleText : String {
        get {
            return invisibleField.text ?? ""
        }
        set {
            self.reloadAppearance()
        }
    }
    
    private var attributes: [NSAttributedString.Key : Any] = [:]
    private var backViews = [UIView]()
    
    // Mark: - Lifecycle
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        self.reload()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.bringSubviewToFront(self.invisibleField)
        self.invisibleField.frame = self.bounds
        
        // back views
        
        var myText = ""
        for _ in 0..<self.properties.numberOfCharacters {
            myText += "0"
        }
        let nsText = NSString(string: myText)
        let textFrame = nsText.boundingRect(with: self.bounds.size,
                                        options: .usesLineFragmentOrigin,
                                        attributes: self.attributes,
                                        context: nil)
        
        
        let actualWidth = textFrame.width
            + (self.appearance.kerning * CGFloat(self.properties.numberOfCharacters))
        let digitWidth = actualWidth / CGFloat(self.properties.numberOfCharacters)
        
        let offset = (self.bounds.width - actualWidth) / 2
        
        for (index, v) in self.backViews.enumerated() {
            let x = CGFloat(index) * digitWidth + offset
            var vFrame = CGRect(x: x,
                                y: -1,
                                width: digitWidth,
                                height: self.frame.height)
            vFrame.origin.x += self.appearance.backOffset / 2
            vFrame.size.width -= self.appearance.backOffset
            v.frame = vFrame
        }
    }
    
    public func reload() {
        
        // Only setup if view showing
        guard self.superview != nil else {
            return
        }
        
        // Debugging ---------------
        // Change alpha for easy debug
        let alpha: CGFloat = 0.0
        self.invisibleField.backgroundColor =  UIColor.white.withAlphaComponent(alpha * 0.8)
        self.invisibleField.tintColor = UIColor.black.withAlphaComponent(alpha)
        self.invisibleField.textColor = UIColor.black.withAlphaComponent(alpha)
        // --------------------------
        
        // Prepare `invisibleField`
        self.invisibleField.text = ""
        self.invisibleField.keyboardType = .numberPad
        self.invisibleField.textAlignment = .center
        if #available(iOS 12.0, *) {
            // Show possible prediction on iOS >= 12
            self.invisibleField.textContentType = .oneTimeCode
            self.invisibleField.autocorrectionType = .yes
        }
        self.addSubview(self.invisibleField)
        self.invisibleField.addTarget(self, action: #selector(reloadAppearance), for: .allEditingEvents)
        
        // Prepare visible field
        self.tintColor = .clear // Hide cursor
        self.contentVerticalAlignment = .center
        
        // Set back views
        for v in self.backViews {
            v.removeFromSuperview()
        }
        self.backViews.removeAll(keepingCapacity: false)
        for _ in 0..<self.properties.numberOfCharacters {
            let v = UIView()
            backViews.append(v)
            self.addSubview(v)
            self.sendSubviewToBack(v)
        }
        
        // Delay fixes kerning offset issue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.reloadAppearance()
        }
    }
    
    // Mark: - Public functions
    
    override public func becomeFirstResponder() -> Bool {
        return self.invisibleField.becomeFirstResponder()
    }
    
    public func animateFailure(_ completion : (() -> Void)? = nil) {
        
        CATransaction.begin()
        CATransaction.setCompletionBlock({
            completion?()
        })
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction.init(name: .linear)
        animation.duration = 0.6
        animation.values = [-14.0, 14.0, -14.0, 14.0, -8.0, 8.0, -4.0, 4.0, 0.0 ]
        layer.add(animation, forKey: "shake")
        
        CATransaction.commit()
    }
    
    public func animateSuccess(with text: String, completion : (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, animations: {
            
            for v in self.backViews {
                v.alpha = 0
            }
            
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.alpha = 0
        }) { _ in
            self.attributedText = NSAttributedString(string: text, attributes: self.attributes)
            UIView.animate(withDuration: 0.2, animations: {
                self.transform = CGAffineTransform.identity
                self.alpha = 1.0
                
            }) { _ in
                completion?()
            }
        }
    }
    
    // Mark: - Private function
    
    // Updates textfield content
    @objc public func reloadAppearance() {
        
        self.sizeToFit()
        
        // Styling backviews
        for v in self.backViews {
            v.alpha = 1.0
            v.backgroundColor = self.appearance.backColor
            v.layer.borderColor = self.appearance.backBorderColor.cgColor
            v.layer.borderWidth = self.appearance.backBorderWidth
            v.layer.cornerRadius = self.appearance.backCornerRadius
        }
        
        if (UIPasteboard.general.string == self.invisibleText && isRightToLeft) {
            self.invisibleField.text = String(self.invisibleText.reversed())
        }
        
        self.sanitizeText()
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let font =  self.appearance.font?.font() ?? self.font ?? UIFont.preferredFont(forTextStyle: .headline)
        self.attributes = [ .paragraphStyle : paragraph,
                            .font : font,
                            .kern : self.appearance.kerning]
        
        // Display
        let attString = NSMutableAttributedString(string: "")
        let loopStride = isRightToLeft
                    ? stride(from: self.properties.numberOfCharacters-1, to: -1, by: -1)
                    : stride(from: 0, to: self.properties.numberOfCharacters, by: 1)
        
        for i in loopStride {
            
            var string = ""
            if i < invisibleText.count {
                let index = invisibleText.index(string.startIndex, offsetBy: i)
                string = String(invisibleText[index])
            } else {
                string = String(self.properties.token)
            }
            
            // Color for active / inactive
            let backIndex = self.isRightToLeft ? self.properties.numberOfCharacters-i-1 : i
            let backView = self.backViews[backIndex]
            if string == String(self.properties.token) {
                attributes[.foregroundColor] = self.appearance.tokenColor
                backView.backgroundColor = self.appearance.backColor
                backView.layer.borderColor = self.appearance.backBorderColor.cgColor
            } else {
                attributes[.foregroundColor] = self.appearance.textColor
                backView.backgroundColor = self.appearance.backActiveColor ?? self.appearance.backColor
                backView.layer.borderColor = self.appearance.backBorderActiveColor?.cgColor ?? self.appearance.backBorderColor.cgColor
            }
            
            // Fix kerning-centering
            let indexForKernFix = isRightToLeft ? 0 : self.properties.numberOfCharacters-1
            if i == indexForKernFix {
                attributes[.kern] = 0.0
            }
            
            attString.append(NSAttributedString(string: string, attributes: attributes))
        }
        
        self.attributedText = attString
        
        if #available(iOS 11.0, *) {
            self.updateCursorPosition()
        }
        
        self.checkCodeValidity()
    }
    
    private func sanitizeText() {
        var text = self.invisibleField.text ?? ""
        text = String(text.lazy.filter(self.properties.validCharacters.contains))
        text = String(text.prefix(self.properties.numberOfCharacters))
        self.invisibleField.text = text
    }
    
    // Always position cursor on last valid character
    private func updateCursorPosition() {
        let offset = min(self.invisibleText.count, self.properties.numberOfCharacters)
        // Only works with a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let position = self.invisibleField.position(from: self.invisibleField.beginningOfDocument, offset: offset) {
                
                let textRange = self.textRange(from: position, to: position)
                self.invisibleField.selectedTextRange = textRange
                
                // Token focus
                if   let attString = self.attributedText?.mutableCopy() as? NSMutableAttributedString,
                     var range = self.invisibleField.selectedRange,
                    range.location >= -1 && range.location < self.properties.numberOfCharacters {
                    
                    // Compute range of focused text
                    if self.isRightToLeft {
                        range.location = self.properties.numberOfCharacters-range.location-1
                    }
                    range.length = 1
                    
                    // Make sure it's a token
                    // before applying it's foreground color preperty
                    let string = attString.string
                    let startIndex = string.index(string.startIndex, offsetBy: range.location)
                    let endIndex = string.index(startIndex, offsetBy: 1)
                    let sub = string[startIndex..<endIndex]
                    if sub == String(self.properties.token) {
                        var atts = attString.attributes(at: range.location, effectiveRange: nil)
                        atts[.foregroundColor] = self.appearance.tokenFocusColor
                            ?? self.appearance.tokenColor
                        attString.setAttributes(atts, range: range)
                        self.attributedText = attString
                    }
                }
                
                // Backview focus
                var backIndex = self.isRightToLeft ? self.properties.numberOfCharacters-offset-1 : offset
                backIndex = min(backIndex, self.properties.numberOfCharacters-1)
                backIndex = max(backIndex, 0)
                let backView = self.backViews[backIndex]
                backView.backgroundColor = self.appearance.backFocusColor ?? self.appearance.backColor
                backView.layer.borderColor = self.appearance.backBorderFocusColor?.cgColor ?? self.appearance.backBorderColor.cgColor
            }
        }
    }
    
 
    
    private func checkCodeValidity() {
        if self.invisibleText.count == self.properties.numberOfCharacters {
            if let pinDelegate = self.properties.delegate {
                let result = isRightToLeft ? String(self.invisibleText.reversed()) : self.invisibleText
                pinDelegate.pinField(self, didFinishWith: result)
            } else {
                print("warning : No pinDelegate set for KAPinField")
            }
        }
    }
}

extension UITextInput {
    var selectedRange: NSRange? {
        guard let range = selectedTextRange else { return nil }
        let location = offset(from: beginningOfDocument, to: range.start)
        let length = offset(from: range.start, to: range.end)
        return NSRange(location: location, length: length)
    }
}

// Mark: - KA_MonospacedFont
// Helper to provide monospaced fonts via literal
public enum KA_MonospacedFont {
    
    case courier(CGFloat)
    case courierBold(CGFloat)
    case courierBoldOblique(CGFloat)
    case courierOblique(CGFloat)
    case courierNewBoldItalic(CGFloat)
    case courierNewBold(CGFloat)
    case courierNewItalic(CGFloat)
    case courierNew(CGFloat)
    case menloBold(CGFloat)
    case menloBoldItalic(CGFloat)
    case menloItalic(CGFloat)
    case menlo(CGFloat)
    
    func font() -> UIFont {
        switch self {
        case .courier(let size) :
            return UIFont(name: "Courier", size: size)!
        case .courierBold(let size) :
            return UIFont(name: "Courier-Bold", size: size)!
        case .courierBoldOblique(let size) :
            return UIFont(name: "Courier-BoldOblique", size: size)!
        case .courierOblique(let size) :
            return UIFont(name: "Courier-Oblique", size: size)!
        case .courierNewBoldItalic(let size) :
            return UIFont(name: "CourierNewPS-BoldItalicMT", size: size)!
        case .courierNewBold(let size) :
            return UIFont(name: "CourierNewPS-BoldMT", size: size)!
        case .courierNewItalic(let size) :
            return UIFont(name: "CourierNewPS-ItalicMT", size: size)!
        case .courierNew(let size) :
            return UIFont(name: "CourierNewPSMT", size: size)!
        case .menloBold(let size) :
            return UIFont(name: "Menlo-Bold", size: size)!
        case .menloBoldItalic(let size) :
            return UIFont(name: "Menlo-BoldItalic", size: size)!
        case .menloItalic(let size) :
            return UIFont(name: "Menlo-Italic", size: size)!
        case .menlo(let size) :
            return UIFont(name: "Menlo-Regular", size: size)!
        }
    }
}
