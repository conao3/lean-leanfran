//! Items and the events that change them.

use crate::spec::items;

#[derive(Clone, Copy, Debug, PartialEq, Eq, leanfran::Model)]
pub enum Kind {
    Tool,
    Part,
}

#[derive(Clone, Debug, PartialEq, Eq, leanfran::Model)]
pub struct Item {
    pub id: u32,
    pub kind: Kind,
    pub qty: u32,
}

#[derive(Clone, Debug, PartialEq, Eq, leanfran::Model)]
pub enum Event {
    Received { id: u32, n: u32 },
    Shipped { id: u32, n: u32 },
    Retired,
}

/// The item after the event: quantities saturate at 0 and `u32::MAX`, events of other items
/// change nothing.
#[leanfran::model(refines = items::apply, ensures(same_id = items::same_id), strategy = crate::item::inputs)]
pub fn apply(it: Item, e: &Event) -> Item {
    match e {
        Event::Received { id, n } if *id == it.id => Item {
            qty: it.qty.saturating_add(*n),
            ..it
        },
        Event::Shipped { id, n } if *id == it.id => Item {
            qty: it.qty.saturating_sub(*n),
            ..it
        },
        Event::Retired => Item { qty: 0, ..it },
        _ => it,
    }
}

#[cfg(test)]
fn inputs() -> impl leanfran::check::proptest::strategy::Strategy<Value = (Item, Event)> {
    use leanfran::check::proptest::prelude::*;
    let kind = prop_oneof![Just(Kind::Tool), Just(Kind::Part)];
    let item = (0u32..4, kind, any::<u32>()).prop_map(|(id, kind, qty)| Item { id, kind, qty });
    let event = prop_oneof![
        (0u32..4, any::<u32>()).prop_map(|(id, n)| Event::Received { id, n }),
        (0u32..4, any::<u32>()).prop_map(|(id, n)| Event::Shipped { id, n }),
        Just(Event::Retired),
    ];
    (item, event)
}
