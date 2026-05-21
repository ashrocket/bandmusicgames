import SpriteKit
import SwiftUI

@MainActor
final class PlayerNode: SKNode {
    let heroID: HalfCourtHeroID
    let team: HalfCourtTeam
    private var character: HalfCourtHero { heroID.character }
    
    private let bodyContainer = SKNode()
    private let shadowNode = SKShapeNode(ellipseIn: CGRect(x: -25, y: -6, width: 50, height: 12))
    private let selectionRing = SKShapeNode(ellipseIn: CGRect(x: -38, y: -12, width: 76, height: 24))
    
    var currentAnimation: HalfCourtPhase = .title // Placeholder
    var facing: CGFloat = 1 {
        didSet {
            bodyContainer.xScale = abs(bodyContainer.xScale) * facing
        }
    }
    
    var jump: CGFloat = 0 {
        didSet {
            bodyContainer.position.y = jump
            shadowNode.alpha = max(0.1, 0.23 - (abs(jump) / 200))
        }
    }

    init(heroID: HalfCourtHeroID, team: HalfCourtTeam) {
        self.heroID = heroID
        self.team = team
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // Shadow
        shadowNode.fillColor = .black.withAlphaComponent(0.23)
        shadowNode.strokeColor = .clear
        addChild(shadowNode)
        
        // Selection Ring
        selectionRing.strokeColor = SKColor(character.hue).withAlphaComponent(0.85)
        selectionRing.lineWidth = 3
        selectionRing.isHidden = true
        addChild(selectionRing)
        
        addChild(bodyContainer)
        drawBody()
    }
    
    func setSelectionActive(_ active: Bool) {
        selectionRing.isHidden = !active
    }

    private func drawBody() {
        let h = character.height * 0.56 // Scale down to fit court
        let skin = SKColor(character.skin)
        let hair = SKColor(character.hair)
        let shirt = SKColor(character.shirt)
        let pants = SKColor(character.pants)
        let shoes = SKColor(character.shoes)

        // Head
        let head = SKShapeNode(ellipseIn: CGRect(x: -16, y: h - 41, width: 32, height: 34))
        head.fillColor = skin
        head.strokeColor = .clear
        bodyContainer.addChild(head)

        // Hair
        drawHair(h: h, hairColor: hair)

        // Shirt
        let shirtNode = SKShapeNode(rect: CGRect(x: -24, y: h - 102, width: 48, height: 64), cornerRadius: 12)
        shirtNode.fillColor = shirt
        shirtNode.strokeColor = .clear
        bodyContainer.addChild(shirtNode)

        // Pants
        let pantsNode = SKShapeNode(rect: CGRect(x: -20, y: h - 133, width: 40, height: 38), cornerRadius: 9)
        pantsNode.fillColor = pants
        pantsNode.strokeColor = .clear
        bodyContainer.addChild(pantsNode)

        // Arms
        let lArm = SKShapeNode()
        let lPath = CGMutablePath()
        lPath.move(to: CGPoint(x: -23, y: h - 50))
        lPath.addLine(to: CGPoint(x: -36, y: h - 78))
        lArm.path = lPath
        lArm.strokeColor = skin
        lArm.lineWidth = 8
        lArm.lineCap = .round
        bodyContainer.addChild(lArm)

        let rArm = SKShapeNode()
        let rPath = CGMutablePath()
        rPath.move(to: CGPoint(x: 23, y: h - 50))
        rPath.addLine(to: CGPoint(x: 36, y: h - 78))
        rArm.path = rPath
        rArm.strokeColor = skin
        rArm.lineWidth = 8
        rArm.lineCap = .round
        bodyContainer.addChild(rArm)

        // Legs
        let lLeg = SKShapeNode()
        let llPath = CGMutablePath()
        llPath.move(to: CGPoint(x: -10, y: h - 128))
        llPath.addLine(to: CGPoint(x: -14, y: -8))
        lLeg.path = llPath
        lLeg.strokeColor = pants.withAlphaComponent(0.9)
        lLeg.lineWidth = 10
        lLeg.lineCap = .round
        bodyContainer.addChild(lLeg)

        let rLeg = SKShapeNode()
        let rlPath = CGMutablePath()
        rlPath.move(to: CGPoint(x: 10, y: h - 128))
        rlPath.addLine(to: CGPoint(x: 14, y: -8))
        rLeg.path = rlPath
        rLeg.strokeColor = pants.withAlphaComponent(0.9)
        rLeg.lineWidth = 10
        rLeg.lineCap = .round
        bodyContainer.addChild(rLeg)

        // Shoes
        let lShoe = SKShapeNode(ellipseIn: CGRect(x: -20, y: -9, width: 22, height: 8))
        lShoe.fillColor = shoes
        lShoe.strokeColor = .clear
        bodyContainer.addChild(lShoe)

        let rShoe = SKShapeNode(ellipseIn: CGRect(x: 2, y: -9, width: 22, height: 8))
        rShoe.fillColor = shoes
        rShoe.strokeColor = .clear
        bodyContainer.addChild(rShoe)
        
        bodyContainer.yScale = -1 // SpriteKit Y is up
        bodyContainer.position.y = 0
    }

    private func drawHair(h: CGFloat, hairColor: SKColor) {
        switch character.hairStyle {
        case .bob:
            let hairNode = SKShapeNode(rect: CGRect(x: -23, y: h - 43, width: 46, height: 46), cornerRadius: 18)
            hairNode.fillColor = hairColor
            hairNode.strokeColor = .clear
            bodyContainer.addChild(hairNode)
        case .long:
            let hairNode = SKShapeNode(rect: CGRect(x: -25, y: h - 71, width: 50, height: 72), cornerRadius: 18)
            hairNode.fillColor = hairColor
            hairNode.strokeColor = .clear
            bodyContainer.addChild(hairNode)
            let band = SKShapeNode(rect: CGRect(x: -24, y: h - 10, width: 48, height: 18), cornerRadius: 8)
            band.fillColor = .black
            band.strokeColor = .clear
            bodyContainer.addChild(band)
        case .beanie:
            let beanie = SKShapeNode(rect: CGRect(x: -20, y: h - 18, width: 40, height: 22), cornerRadius: 10)
            beanie.fillColor = SKColor(red: 0.72, green: 0.72, blue: 0.72, alpha: 1.0)
            beanie.strokeColor = .clear
            bodyContainer.addChild(beanie)
        case .glasses:
            let hairNode = SKShapeNode(ellipseIn: CGRect(x: -20, y: h - 32, width: 40, height: 30))
            hairNode.fillColor = hairColor
            hairNode.strokeColor = .clear
            bodyContainer.addChild(hairNode)
            
            // Glasses
            let lLens = SKShapeNode(ellipseIn: CGRect(x: -13, y: h - 25, width: 11, height: 8))
            lLens.strokeColor = .black
            lLens.lineWidth = 1.5
            bodyContainer.addChild(lLens)
            
            let rLens = SKShapeNode(ellipseIn: CGRect(x: 2, y: h - 25, width: 11, height: 8))
            rLens.strokeColor = .black
            rLens.lineWidth = 1.5
            bodyContainer.addChild(rLens)
        }
    }
}
