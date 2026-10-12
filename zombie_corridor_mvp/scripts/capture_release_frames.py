#!/usr/bin/env python3
"""Capture the game's own rendered Viewport; never bypass or unlock the desktop."""
from runtime import *
owned=Processes();pnum=port()
try:
    server,l=owned.start('render-server',['--server','--port',pnum,'--scenario','play'],True);owned.wait_ready(server,l,'SERVER_READY')
    gui,l=owned.start('render-gameplay',['--client','--port',pnum,'--capture-frame',ROOT/'results/gameplay.png','--capture-delay',4,'--capture-debug','--duration',6],True,True);owned.wait_ready(gui,l,'CLIENT_READY');assert gui.wait(timeout=15)==0;assert 'FRAME_CAPTURE 0' in l.read_text()
    menu,l=owned.start('render-menu',['--capture-frame',ROOT/'results/menu.png','--capture-delay',2,'--duration',4],True,True);assert menu.wait(timeout=10)==0;assert 'FRAME_CAPTURE 0' in l.read_text()
    owned.check_logs();print('EXPORTED_VIEWPORT_PASS gameplay/menu; native keyboard/mouse not exercised')
finally:owned.cleanup()
