// The MIT License (MIT)
//
// Copyright (c) 2021 Alexander Grebenyuk (github.com/kean).

import UIKit
import RxSwift
import RxCocoa

// MARK: - RxObservableObject

public protocol RxObservableObject: AnyObject {
    var objectWillChange: PublishRelay<Void> { get }
}

public extension RxObservableObject {
    var objectWillChange: PublishRelay<Void> {
        if let relay = objc_getAssociatedObject(self, &objectWillChangeAssociatedKey) as? PublishRelay<Void> {
            return relay
        }
        let relay = PublishRelay<Void>()
        registerPublishedProperties(objectWillChange: relay)
        objc_setAssociatedObject(self, &objectWillChangeAssociatedKey, relay, .OBJC_ASSOCIATION_RETAIN)
        return relay
    }
}

private extension RxObservableObject {
    func registerPublishedProperties(objectWillChange: PublishRelay<Void>) {
        let allPublished = Mirror(reflecting: self)
            .children
            .compactMap { $0.value as? RxPublishedProtocol }
        let disposeBag = getDisposeBag(for: self)
        for published in allPublished {
            published.publishedWillChange.bind(to: objectWillChange).disposed(by: disposeBag)
        }
    }
}

private func getDisposeBag(for object: AnyObject) -> DisposeBag {
    if let disposeBag = objc_getAssociatedObject(object, &disposeBagAssociatedKey) as? DisposeBag {
        return disposeBag
    }
    let disposeBag = DisposeBag()
    objc_setAssociatedObject(object, &disposeBagAssociatedKey, disposeBag, .OBJC_ASSOCIATION_RETAIN)
    return disposeBag
}

private var objectWillChangeAssociatedKey = "RxObservableObject.objectWillChange.AssociatedKey"
private var disposeBagAssociatedKey = "RxObservableObject.disposeBag.AssociatedKey"

// MARK: - RxPublished

@propertyWrapper
public struct RxPublished<Value>: RxPublishedProtocol {
    private let relay: BehaviorRelay<Value>
    var publishedWillChange: Observable<Void> { relay.map { _ in () } }

    public init(wrappedValue: Value) {
        relay = .init(value: wrappedValue)
    }

    public var wrappedValue: Value {
        set { relay.accept(newValue) }
        get { relay.value }
    }

    public var projectedValue: BehaviorRelay<Value> {
        relay
    }
}

protocol RxPublishedProtocol {
    var publishedWillChange: Observable<Void> { get }
}

// MARK: - RxView

public protocol RxView: AnyObject {
    /// Gets called whenever the observable object changes.
    func refreshView()
}

public extension RxView {
    var disposeBag: DisposeBag {
        getDisposeBag(for: self)
    }
}

public extension RxView where Self: UIViewController {
    /// Observes `objectWillChange` and automatically called refresh.
    func bind(_ object: RxObservableObject) {
        let fakeView = hookIntoRenderSystem(container: view)
        _bind(object, self, fakeView)
    }
}

public extension RxView where Self: UIView {
    /// Observes `objectWillChange` and automatically called refresh.
    func bind(_ object: RxObservableObject) {
        _bind(object, self, hookIntoRenderSystem(container: self))
    }
}

private func _bind(_ object: RxObservableObject, _ view: RxView, _ fakeView: UIView) {
    let disposeBag = getDisposeBag(for: view)

    view.refreshView()
    object.objectWillChange
        .subscribe(onNext: { [weak fakeView] in fakeView?.setNeedsLayout() })
        .disposed(by: disposeBag)

    fakeView.rx.sentMessage(#selector(UIView.layoutSubviews))
        .subscribe(onNext: { [weak view] _ in view?.refreshView() })
        .disposed(by: disposeBag)
}

// The idea is to refresh the view with the new data only when the screen needs
// to be re-rendered. We use a fake view to avoid re-rendering actualy stuff that
// doesn't need re-layout.
private func hookIntoRenderSystem(container: UIView) -> UIView {
    if let fakeView = objc_getAssociatedObject(container, &fakeViewAssociatedKey) as? UIView {
        return fakeView
    }
    let fakeView = UIView()
    fakeView.isHidden = true
    container.addSubview(fakeView)
    objc_setAssociatedObject(container, &fakeViewAssociatedKey, fakeView, .OBJC_ASSOCIATION_RETAIN)
    return fakeView
}

private var fakeViewAssociatedKey = "RxView.fakeViewAssociatedKey.AssociatedKey"
