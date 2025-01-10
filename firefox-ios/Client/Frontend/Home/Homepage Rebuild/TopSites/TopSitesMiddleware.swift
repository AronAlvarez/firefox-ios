// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Redux
import Storage

final class TopSitesMiddleware: FeatureFlaggable {
    private let topSitesManager: TopSitesManagerInterface
    private let unifiedAdsTelemetry: UnifiedAdsCallbackTelemetry
    private let logger: Logger

    // Raw data to build top sites with, we may want to revisit and fetch only the number of top sites we want
    // but keeping logic consistent for now
    private var otherSites: [TopSiteState] = []
    private var sponsoredTiles: [SponsoredTile] = []

    init(
        profile: Profile = AppContainer.shared.resolve(),
        topSitesManager: TopSitesManagerInterface? = nil,
        logger: Logger = DefaultLogger.shared,
        unifiedAdsTelemetry: UnifiedAdsCallbackTelemetry = DefaultUnifiedAdsCallbackTelemetry()
    ) {
        self.topSitesManager = topSitesManager ?? TopSitesManager(
            profile: profile,
            googleTopSiteManager: GoogleTopSiteManager(
                prefs: profile.prefs
            ),
            topSiteHistoryManager: TopSiteHistoryManager(profile: profile),
            searchEnginesManager: profile.searchEnginesManager
        )
        self.logger = logger
        self.unifiedAdsTelemetry = unifiedAdsTelemetry
    }

    lazy var topSitesProvider: Middleware<AppState> = { state, action in
        switch action.actionType {
        case HomepageActionType.initialize,
            TopSitesActionType.fetchTopSites,
            TopSitesActionType.toggleShowSponsoredSettings:
            self.getTopSitesDataAndUpdateState(for: action)
        case ContextMenuActionType.tappedOnPinTopSite:
            guard let site = self.getSite(for: action) else { return }
            self.topSitesManager.pinTopSite(site)
        case ContextMenuActionType.tappedOnUnpinTopSite:
            guard let site = self.getSite(for: action) else { return }
            self.topSitesManager.unpinTopSite(site)
        case ContextMenuActionType.tappedOnRemoveTopSite:
            guard let site = self.getSite(for: action) else { return }
            self.topSitesManager.removeTopSite(site)
        case TopSitesActionType.cellConfigured:
            self.handleSponsoredImpressionTracking(for: action)
        case TopSitesActionType.didSelectItem:
            self.handleSponsoredClickTracking(for: action)
        default:
            break
        }
    }

    private func getSite(for action: Action) -> Site? {
        guard let site = (action as? ContextMenuAction)?.site else {
            self.logger.log(
                "Unable to retrieve site for \(action.actionType)",
                level: .warning,
                category: .homepage
            )
            return nil
        }
        return site
    }

    private func getTopSitesDataAndUpdateState(for action: Action) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    self.otherSites = await self.topSitesManager.getOtherSites()
                    await self.updateTopSites(
                        for: action.windowUUID,
                        otherSites: self.otherSites,
                        sponsoredTiles: self.sponsoredTiles
                    )
                }
                group.addTask {
                    self.sponsoredTiles = await self.topSitesManager.fetchSponsoredSites()
                    await self.updateTopSites(
                        for: action.windowUUID,
                        otherSites: self.otherSites,
                        sponsoredTiles: self.sponsoredTiles
                    )
                }

                await group.waitForAll()
                await updateTopSites(
                    for: action.windowUUID,
                    otherSites: self.otherSites,
                    sponsoredTiles: self.sponsoredTiles
                )
            }
        }
    }

    private func updateTopSites(
        for windowUUID: WindowUUID,
        otherSites: [TopSiteState],
        sponsoredTiles: [SponsoredTile]
    ) async {
        let topSites = await self.topSitesManager.recalculateTopSites(
            otherSites: otherSites,
            sponsoredSites: sponsoredTiles
        )
        store.dispatch(
            TopSitesAction(
                topSites: topSites,
                windowUUID: windowUUID,
                actionType: TopSitesMiddlewareActionType.retrievedUpdatedSites
            )
        )
    }

    // MARK: Telemetry
    private func handleSponsoredImpressionTracking(for action: Action) {
        guard let telemetryMetadata = (action as? TopSitesAction)?.telemetryMetadata else {
            self.logger.log(
                "Unable to retrieve telemetryMetadata for \(action.actionType)",
                level: .warning,
                category: .homepage
            )
            return
        }
//            guard !hasSentImpressionForTile(topSiteState) else { return }
        // Only sending sponsored tile impressions for now
        guard let tile = telemetryMetadata.topSiteState.site as? SponsoredTile else { return }
        if featureFlags.isFeatureEnabled(.unifiedAds, checking: .buildOnly) {
            unifiedAdsTelemetry.sendImpressionTelemetry(tile: tile, position: telemetryMetadata.position)
        } else {
            SponsoredTileTelemetry.sendImpressionTelemetry(tile: tile, position: telemetryMetadata.position)
        }
    }

    private func handleSponsoredClickTracking(for action: Action) {
        guard let telemetryMetadata = (action as? TopSitesAction)?.telemetryMetadata else {
            self.logger.log(
                "Unable to retrieve telemetryMetadata for \(action.actionType)",
                level: .warning,
                category: .homepage
            )
            return
        }
        guard let tile = telemetryMetadata.topSiteState.site as? SponsoredTile else { return }
        if featureFlags.isFeatureEnabled(.unifiedAds, checking: .buildOnly) {
            unifiedAdsTelemetry.sendClickTelemetry(tile: tile, position: telemetryMetadata.position)
        } else {
            SponsoredTileTelemetry.sendClickTelemetry(tile: tile, position: telemetryMetadata.position)
        }
    }
}
