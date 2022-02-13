# Created by wes148 at 14/02/2022
import unittest

from lvft_reader import ditto_utils


class MetricCalcTest(unittest.TestCase):

    def test_impedance_matrix_conversion(self):
        '''
        Checks the impedance matrix conversion code using Fred Geth's validated matrix and results.
        '''
        import numpy as np

        impedance_matrix = np.matrix([
            [0.3113 + 1.3922j, 0.0953 + 0.7835j, 0.0953 + 0.7835j],
            [0.0953 + 0.7835j, 0.3113 + 1.3922j, 0.0953 + 0.7835j],
            [0.0953 + 0.7835j, 0.0953 + 0.7835j, 0.3113 + 1.3922j]])

        R0, X0, R1, X1 = ditto_utils.get_impedance_from_matrix(impedance_matrix)
        self.assertAlmostEqual(R0, 0.50, 2)
        self.assertAlmostEqual(X0, 2.96, 2)
        self.assertAlmostEqual(R1, 0.22, 2)
        self.assertAlmostEqual(X1, 0.61, 2)
