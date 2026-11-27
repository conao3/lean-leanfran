<?php

declare(strict_types=1);

use GenerateTest\External\Choice\Flag as ExternalFlag;
use GenerateTest\External\Settings\Level;
use GenerateTest\Generated\Area\Area;
use GenerateTest\Generated\Area\Shapes_PacketShapesStatus;
use GenerateTest\Generated\Choice\Flag;
use GenerateTest\Generated\Inheritance\Sample;
use GenerateTest\Generated\Models\Area_Seed;
use GenerateTest\Generated\Models\Counter;
use GenerateTest\Generated\Models\Point;
use GenerateTest\Generated\Models\Shapes;
use GenerateTest\Generated\Models\Status;
use GenerateTest\Generated\Report\Line;
use GenerateTest\Generated\Report\Report;
use GenerateTest\Generated\Report\Shapes_PacketBool;

$loader = require $argv[1];
$loader->addPsr4('GenerateTest\\External\\', __DIR__ . '/external');
$loader->addPsr4('GenerateTest\\Generated\\', __DIR__ . '/generated');

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

$point = new Point(1, 2);
$rect = Area::place(new Area_Seed($point));
check($rect->origin == $point, 'Area uses Point and Area_Seed from the Shapes module');
check(Area::count(new Counter(4))->value === 5, 'Area uses Counter from a module without functions');
check(Area::shapeCount(new Shapes(6)) === 6, 'Area uses the type named after the Shapes module');
check(Report::total([new Line('', $point, $rect)]) === 12, 'Report uses Point and Rect from their declaring modules');
$sample = new Sample(new Area_Seed($point), 'sample');
check($sample->seed->point == $point, 'A structure extending a shared parent uses the parent’s field types');

$packet = Area::packet(Status::Ready);
check($packet instanceof Shapes_PacketShapesStatus, 'Area owns Packet Status');
check(Report::status($packet) === Status::Ready, 'Report uses the same Packet Status class');
check(Report::boolean(new Shapes_PacketBool(true)), 'Packet Bool has a separate definition');
check(Report::grams(Area::weigh(7)) === 7, 'Report shares the type outside the table');

check(Area::mainFlag(new Flag(true))->enabled, 'Area uses the current table’s Choice.Flag');
check(Report::externalFlag(new ExternalFlag(true))->enabled, 'Report uses its module binding for Choice.Flag');
check(Report::setting(new Level(3))->value === 3, 'Report uses the table binding for Settings.Level');

foreach ([
    'Rect',
    'Shapes_Point',
    'Shapes_PacketShapesStatus',
    'Loose_Weight',
    'Choice_Flag',
    'Settings_Level',
] as $type) {
    check(!class_exists("GenerateTest\\Generated\\Report\\{$type}"), "Report generated an extra {$type} class");
}
