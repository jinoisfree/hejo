import Foundation
@main enum VerticalRegression {
    static func main() {
        let sprite=CGRect(x:1151,y:406,width:192,height:208)
        let chat=CGRect(x:600,y:300,width:428,height:500)
        let screen=CGRect(x:0,y:30,width:1512,height:1050)
        let body=PetLayout.placementSprite(in:sprite)
        let p=PetPlacement(globalSprite:sprite,globalBubble:chat,expanded:true).dragged(by:.zero,visibleFrame:screen)
        let vertical=p.globalBubble.maxY <= body.minY || p.globalBubble.minY >= body.maxY
        let passed=p.globalSprite==sprite && vertical
        print("vertical_placement=\(vertical), pet_unchanged=\(p.globalSprite==sprite)")
        exit(passed ? 0:1)
    }
}
