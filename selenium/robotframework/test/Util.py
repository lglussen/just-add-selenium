from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn
import time


class Util(object):
    def __init__(self):
        self.builtin = BuiltIn()

    def horizontal_window_layout(self, *, display_size=None):
        if display_size is None:
            d_width, d_height = self.get_display_size(False)
        else:
            d_width, d_height = display_size
        handles = self.builtin.run_keyword("Get Window Handles")
        num_windows = len(handles)
        width = d_width / num_windows

        logger.info(f'window width: {width}',  also_console=True)
        for x in range(0, num_windows):
            logger.info(f'{x} of {num_windows}',  also_console=True)
            window = handles[x]
            self.builtin.run_keyword("Switch Window", window)
            self.builtin.run_keyword("Set Window Size", width, d_height)
            self.builtin.run_keyword("Set Window Position", x*width, 0)


    def auto_layout(self):
        d_w, d_h = self.get_display_size(False)
        handles = self.builtin.run_keyword("Get Window Handles")
        num_windows = len(handles)
        
        # if matching the screen aspect ratio
        ww = (d_w / d_h) * wh
        wh = (d_h / d_w) * ww


    def get_display_size(self, restore=True):
        if restore:
            org_w, org_h = self.builtin.run_keyword("Get Window Size")
            org_x, org_y = self.builtin.run_keyword("Get Window Position")
        self.builtin.run_keyword("Maximize Browser Window")
        time.sleep(2)
        w, h = self.builtin.run_keyword("Get Window Size")
        if restore:
            self.builtin.run_keyword("Set Window Size", org_w, org_h)
            self.builtin.run_keyword("Set Window Position", org_x, org_y)
        logger.info(f'display size: {w}px, {h}px',  also_console=True)
        return w, h


#        plit Window Layout
#  Maximize Browser Window
#  ${w}  ${h}=  Get Window Size
#  ${handles}=  Get Window Handles
#  ${divisor}=  Get length  ${handles}
#  ${midway}  evaluate   $w / 2
#  Log To Console  w=${w} h=${h} handles=${divisor} midway=${midway}


