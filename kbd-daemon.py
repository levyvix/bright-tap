#!/usr/bin/env python3
import asyncio
import evdev
from pathlib import Path

TIMEOUT = 5


def find_backlight():
    """Auto-detectar arquivo de backlight de teclado em /sys/class/leds/"""
    leds_path = Path("/sys/class/leds")

    if not leds_path.exists():
        return None

    # Procurar por padrões comuns de backlight de teclado
    patterns = [
        "*::kbd_backlight",  # ThinkPad, Dell, etc
        "*backlight*",       # Generic
        "kbd_backlight",     # Fallback
    ]

    for pattern in patterns:
        for led_dir in sorted(leds_path.glob(pattern)):
            brightness_file = led_dir / "brightness"
            if brightness_file.exists():
                return str(brightness_file)

    return None


BACKLIGHT = find_backlight()


def set_light(value: int):
    if not BACKLIGHT:
        return
    with open(BACKLIGHT, "w") as f:
        f.write(str(value))


def find_keyboards():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    keyboards = [d for d in devices if evdev.ecodes.EV_KEY in d.capabilities()]
    # Excluir touchpads, mice e outros dispositivos que não são teclados
    exclude_keywords = ("touchpad", "mouse", "trackpad", "trackpoint")
    return [d for d in keyboards if not any(kw in d.name.lower() for kw in exclude_keywords)]


async def monitor(device, timer_reset):
    async for event in device.async_read_loop():
        if event.type == evdev.ecodes.EV_KEY and event.value == 1:
            timer_reset.set()


async def timeout_handler(timer_reset):
    while True:
        await timer_reset.wait()
        timer_reset.clear()
        set_light(1)
        while True:
            try:
                await asyncio.wait_for(timer_reset.wait(), timeout=TIMEOUT)
                timer_reset.clear()
            except asyncio.TimeoutError:
                set_light(0)
                break


async def main():
    if not BACKLIGHT:
        print("error: no keyboard backlight found")
        print("supported devices: ThinkPad, Dell, HP, ASUS, and generic Linux laptops")
        return

    print(f"backlight: {BACKLIGHT}")

    keyboards = find_keyboards()
    if not keyboards:
        print("error: no keyboards found")
        return

    print(f"monitoring {len(keyboards)} device(s):")
    for d in keyboards:
        print(f"  - {d.path}: {d.name}")

    timer_reset = asyncio.Event()
    set_light(0)

    tasks = [asyncio.create_task(monitor(d, timer_reset)) for d in keyboards]
    tasks.append(asyncio.create_task(timeout_handler(timer_reset)))
    await asyncio.gather(*tasks)


asyncio.run(main())
