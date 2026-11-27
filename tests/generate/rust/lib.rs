mod external;
mod generated;

use generated::{choice, report, shapes, shapes_area};

pub fn check(point: shapes::Point) -> bool {
    let template = shapes::Template {
        seed: shapes::AreaSeed { point },
    };
    let count = shapes_area::count(shapes::Counter { value: 4 });
    let rect: shapes_area::Rect = shapes_area::place(template.seed);
    let line = report::Line {
        label: String::new(),
        origin: rect.origin.clone(),
        size: rect,
    };
    let _ = report::total(vec![line]);
    let packet = shapes_area::packet(shapes::Status::Ready);
    let main_flag: choice::Flag = shapes_area::main_flag(choice::Flag { enabled: true });
    let external_flag: external::choice::Flag =
        report::external_flag(external::choice::Flag { enabled: true });
    let setting: external::settings::Level =
        report::setting(external::settings::Level { value: 3 });
    count.value == 5
        && matches!(report::status(packet), shapes::Status::Ready)
        && report::boolean(report::ShapesPacketBool { payload: true })
        && main_flag.enabled
        && external_flag.enabled
        && setting.value == 3
        && report::grams(shapes_area::weigh(7)) == 7
        && shapes_area::shape_count(shapes::Shapes { count: 6 }) == 6
}
