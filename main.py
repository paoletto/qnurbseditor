#####################################################################
# Copyright (C) 2023- Paolo Angelelli <paoletto@gmail.com>
#
# This work is licensed under the terms of the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
# To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# In addition to the above,
# - The use of this work for training artificial intelligence is prohibited for both commercial and non-commercial use.
# - Any and all donation options in derivative work must be the same as in the original work.
# - All use of this work outside of the above terms must be explicitly agreed upon in advance with the exclusive copyright owner(s).
# - Any derivative work must retain the above copyright and acknowledge that any and all use of the derivative work outside the above terms
#   must be explicitly agreed upon in advance with the exclusive copyright owner(s) of the original work.
#####################################################################

# This Python file uses the following encoding: utf-8
import sys
import os

from PySide2.QtCore import QCoreApplication, QObject, Signal, Property, QUrl, Slot, QPointF, QSizeF, QDataStream, QFile, QIODevice, QFileInfo
from PySide2.QtWidgets import QFileDialog, QMessageBox, QApplication
from PySide2.QtGui import QGuiApplication, QVector2D
from PySide2.QtQml import QQmlApplicationEngine
from PySide2.QtQuick import *

from geomdl import NURBS
from geomdl import fitting
from geomdl import multi
from geomdl import operations

from geomdl.visualization import VisMPL
import numpy as np
from scipy.spatial.transform import Rotation as R
import operator
import math
from matplotlib.axes import Axes
import matplotlib.pyplot as plt

import json
import sys
import os
import imp
import traceback

def urlToPath(s):
    if (QUrl(s).isLocalFile()):
        return QUrl(s).toLocalFile()
    return s

def scale(v, scaleFactors):
    return list(map(operator.mul, v , scaleFactors))

def translate(p, offset):
    return list(map(operator.add, p , offset))

def rotate(p, deg, axis):
    rotation_radians = np.radians(deg)
    rotation_axis = np.array(axis)
    rotation_vector = rotation_radians * rotation_axis
    rotation = R.from_rotvec(rotation_vector)
    return list(rotation.apply(p))

def translateAll(v, offset):
    return [ list(map(operator.add, x , offset)) for x in v ]

def scaleAll(v, offset):
    return [ list(map(operator.mul, x , offset)) for x in v ]

def rotateAll(v, angle, axis):
    return [ rotate(x, angle, axis) for x in v ]


def unit_vector(vector):
    """ Returns the unit vector of the vector.  """
    return list(np.array(vector) / np.linalg.norm(np.array(vector)))

def angle_between(v1, v2):
    """ Returns the angle in radians between vectors 'v1' and 'v2'::

            >>> angle_between((1, 0, 0), (0, 1, 0))
            1.5707963267948966
            >>> angle_between((1, 0, 0), (1, 0, 0))
            0.0
            >>> angle_between((1, 0, 0), (-1, 0, 0))
            3.141592653589793
    """
    v1_u = unit_vector(v1)
    v2_u = unit_vector(v2)
    return math.degrees(np.arccos(np.clip(np.dot(v1_u, v2_u), -1.0, 1.0)))

def dotproduct(v1, v2):
  return sum((a*b) for a, b in zip(v1, v2))

def length(v):
  return math.sqrt(dotproduct(v, v))

def angle(v1, v2):
  return math.degrees(math.acos(dotproduct(v1, v2) / (length(v1) * length(v2))))

def ellipse3d(t, a, b):
    return [a * math.cos(math.radians(t)), b * math.sin(math.radians(t)), 0]

def ellipticShape(radius, ratio):
    shape = []
    shapeHeight = radius * 2
    shapeWidth = shapeHeight * ratio * 2
    for alpha in range(360,179,-18):
        pos = ellipse3d(alpha, radius * ratio, radius)
        shape.append(pos)

    shape = translateAll(shape, [shapeWidth * 0.5, shapeHeight, 0])
    shapeYZ = rotateAll(translateAll(shape, [-0.5 * shapeWidth, -0.5 * shapeHeight, 0]), -90, [0, 1, 0])
    return shapeYZ

def toFile(data, varname, filepath):
    text_file = open(filepath, "w")
    text_file.write(varname)
    text_file.write(" = ")
    text_file.write(str(data))
    text_file.write(";\n")
    text_file.close()

class QNURBS(QObject):

    curveChanged = Signal()
    degreeChanged = Signal()
    stepsChanged = Signal()
    fileNameChanged = Signal()
    bgPosChanged = Signal()
    bgSizeChanged = Signal()

    def __init__(self, parent=None):
        QObject.__init__(self, parent)
        self.m_controlPoints = []
        self.m_curveDirty = False
        self.m_curve = []
        self.m_tangents = []
        self.m_tangentAngles = []
        self.m_degree = 4
        self.m_steps = 100
        self.m_bgPos = QPointF(0,0)
        self.m_bgSize = QSizeF(0,0)
        self.m_lastFname = None

    def markDirty(self):
        self.m_curveDirty = True
        self.curveChanged.emit()

    def setBgPos(self, pos):
        if (self.m_bgPos == pos):
            return
        self.m_bgPos=pos
        self.bgPosChanged.emit()
        self.markDirty()

    def bgPos(self):
        return self.m_bgPos

    def setBgSize(self, sz):
        if (self.m_bgSize == sz):
            return
        self.m_bgSize=sz
        self.bgSizeChanged.emit()
        self.markDirty()

    def bgSize(self):
        return self.m_bgSize

    def setSteps(self, s):
        if (self.m_steps == s):
            return
        self.m_steps = s
        self.stepsChanged.emit()
        self.markDirty()

    def setDegree(self, dg):
        if (self.m_degree == dg):
            return
        self.m_degree = dg
        self.degreeChanged.emit()
        self.markDirty()

    def steps(self):
        return self.m_steps

    def degree(self):
        return self.m_degree

    def filename(self):
        return self.m_lastFname;

    @Slot(str, result="bool")
    def fileExists(self, fp):
        fi = QFileInfo(urlToPath(fp))
        return fi.exists()

    @Slot(str, result=str)
    def filePathToName(self, fp):
        fi = QFileInfo(urlToPath(fp))
        return fi.fileName()

    @Slot(str)
    def runScript(self, fp):
        fi = QFileInfo(urlToPath(fp))
        dd = fi.dir()
        sys.path.append(dd.absolutePath()) # needed to allow fp to import stuff from its own dir
        module_name = fi.baseName()
        md = imp.load_source(module_name, urlToPath(fp))
        try:
            return md.run({"curve" : self.m_curve,
                           "tangents" : self.m_tangents,
                           "tangentAngles" : self.m_tangentAngles})
        except Exception, e:
            traceback.print_exc()

    @Slot(result="QVariantList")
    def controlPoints(self):
        return self.m_controlPoints

    @Slot("QVariantList")
    def update(self, controlPoints):  # add degree, knot vector
        ctrlPts = []

        for c in controlPoints:
           ctrlPts.append([c.x(), c.y()])
        if (self.m_controlPoints == ctrlPts):
            return
        self.m_controlPoints = ctrlPts
        self.markDirty()

    def updateCurve(self):
        if not self.m_curveDirty:
            return

        self.m_curveDirty = False
        self.m_curve = []
        self.m_tangents = []
        self.m_tangentAngles = []
        if (len(self.m_controlPoints) < 3): # hardcode for now 6 points 4 degree
            return self.m_curve

        # do update
        c1 = NURBS.Curve()
        c1.degree = min(len(self.m_controlPoints) - 1, self.m_degree)
        c1.ctrlpts =  self.m_controlPoints

        knots = [1] * (c1.degree + len(self.m_controlPoints) + 1)
        for i in range(0, len(knots)  / 2):
            knots[i] = 0
        if (len(knots) % 2):
            knots[len(knots) / 2] = 0.5

        rangeToSubdivide = range(c1.degree + 1 , len(knots) - c1.degree - 1)
        step = 1.0 / (len(rangeToSubdivide) + 1)
        cntr = 0
        for i in rangeToSubdivide:
            cntr += 1
            knots[i] = cntr * step

        c1.knotvector = knots
        c1.delta = 0.05

        tStepping = float(self.m_steps)
        stops = [p/tStepping for p in range(0, int(tStepping) + 1)]

        for s in stops:
            p = c1.evaluate_single(s)
            t = operations.tangent(c1, s)
            self.m_curve.append(QPointF(p[0],p[1]))
            tgt = t[1]
            tgt = QVector2D(tgt[0],tgt[1]).normalized()
            self.m_tangents.append(tgt.toPointF())
            self.m_tangentAngles.append(-math.degrees(math.atan2(tgt.y(), tgt.x())))

    def curve(self):
        if self.m_curveDirty:
            self.updateCurve()
        return self.m_curve

    def tangents(self):
        if self.m_curveDirty:
            self.updateCurve()
        return self.m_tangentAngles

    @Slot("QUrl")
    def load(self, fileName):
        pass
        print "Reading from ",fileName
        loader = QFile(fileName.toLocalFile())
        if(not loader.open(QFile.ReadOnly)):
            print "Cant open file"
            return;

        serialized = str(loader.readAll())

        values = json.loads(serialized)

        self.m_lastFname = fileName
        self.fileNameChanged.emit()

        if ("steps" in values):
            self.m_steps = values["steps"]
            self.stepsChanged.emit()
        if ("degree" in values):
            self.m_degree = values["degree"]
            self.degreeChanged.emit()
        if ("control_points" in values):
            self.m_controlPoints = values["control_points"]
            self.markDirty()

        if ("background_position" in values):
            saved = values["background_position"]
            self.m_bgPos.setX(saved[0])
            self.m_bgPos.setY(saved[1])
            self.bgPosChanged.emit()
            self.markDirty()

        if ("background_size" in values):
            saved = values["background_size"]
            self.m_bgSize.setWidth(saved[0])
            self.m_bgSize.setHeight(saved[1])
            self.bgSizeChanged.emit()
            self.markDirty()

    def write(self, filePath):
        if (not filePath):
            return
        values = {}

        values["control_points"] = self.m_controlPoints
        values["steps"] = self.m_steps
        values["degree"] = self.m_degree
        values["background_position"] = (self.m_bgPos.x(), self.m_bgPos.y())
        values["background_size"] = (self.m_bgSize.width(), self.m_bgSize.height())
        serialized = json.dumps(values)


        self.m_lastFname = filePath
        self.fileNameChanged.emit()
        myFile = QFile(str(filePath))
        if(not myFile.open(QIODevice.WriteOnly)):
            return;
        myFile.write(serialized)
        myFile.close()


    @Slot("QUrl")
    def save(self, fileUrl):
        if (not fileUrl):
            return

        self.write(fileUrl.toLocalFile())


    @Slot()
    def requestWrite(self): # spins a dialog
        # Set up and display file dialog
        dialog = QFileDialog()

        dialog.setWindowTitle("Save to File")
        dialog.setFileMode(QFileDialog.AnyFile)
        dialog.setAcceptMode(QFileDialog.AcceptSave)

        if sys.platform == "linux" and "KDE_FULL_SESSION" in os.environ:
            dialog.setOption(QFileDialog.DontUseNativeDialog)

        if not dialog.exec_():
            print "raise OutputDeviceError.UserCanceledError()"
            return

        save_path = dialog.directory().absolutePath()
        print "Save path: ",save_path

        # Get file name from file dialog
        file_name = dialog.selectedFiles()[0]
        print "Writing to [%s]..." % file_name

        if os.path.exists(file_name):
            result = QMessageBox.question(None, "File Already Exists", "The file <filename>{0}</filename> already exists. Are you sure you want to overwrite it?".format(file_name))
            if result == QMessageBox.No:
                print "raise OutputDeviceError.UserCanceledError()"
                return

        print "Writing to ",file_name
        self.write(file_name)

    #
    # Props
    #

    bgPos = Property("QPointF", fget=bgPos, fset=setBgPos, notify=bgPosChanged)
    bgSize = Property("QSizeF", fget=bgSize, fset=setBgSize, notify=bgSizeChanged)
    steps = Property(int, fget=steps, fset=setSteps, notify=stepsChanged)
    degree = Property(int, fget=degree, fset=setDegree, notify=degreeChanged)
    fileName = Property(str, fget=filename, notify=fileNameChanged)
    curve = Property("QVariantList", fget=curve, notify=curveChanged)
    tangents = Property("QVariantList", fget=tangents, notify=curveChanged)

if __name__ == "__main__":
    QCoreApplication.setOrganizationName( "qnurbseditor" );
    QCoreApplication.setOrganizationDomain( "qnurbseditor.com" );

    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    nurbs = QNURBS()
    engine.rootContext().setContextProperty("NURBS", nurbs)
    engine.load(os.path.join(os.path.dirname(__file__), "main.qml"))

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec_())
