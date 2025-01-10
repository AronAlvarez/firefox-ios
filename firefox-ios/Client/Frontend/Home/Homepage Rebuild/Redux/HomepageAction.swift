// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Redux

final class HomepageAction: Action {
    var seenOnce: Bool?
    var showiPadSetup: Bool?

    init(seenOnce: Bool? = nil, showiPadSetup: Bool? = nil, windowUUID: WindowUUID, actionType: any ActionType) {
        self.seenOnce = seenOnce
        self.showiPadSetup = showiPadSetup
        super.init(windowUUID: windowUUID, actionType: actionType)
    }
}

enum HomepageActionType: ActionType {
    case initialize
    case traitCollectionDidChange
    case viewDidAppear
    case viewWillDisappear
}
