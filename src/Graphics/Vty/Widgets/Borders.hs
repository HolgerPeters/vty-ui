-- |This module provides visual borders to be placed between and
-- around widgets.
module Graphics.Vty.Widgets.Borders
    ( Bordered
    , HBorder
    , VBorder
    , vBorder
    , hBorder
    , vBorderWith
    , hBorderWith
    , bordered
    )
where

import Control.Monad.Trans
    ( MonadIO
    , liftIO
    )
import Control.Monad.Reader
    ( ask
    )
import Control.Monad.State
    ( StateT
    , get
    )
import Graphics.Vty
    ( Attr
    , DisplayRegion(DisplayRegion)
    , Image
    , char_fill
    , region_height
    , region_width
    , image_width
    , image_height
    , vert_cat
    , horiz_cat
    )
import Graphics.Vty.Widgets.Rendering
    ( WidgetImpl(..)
    , Widget
    , newWidget
    , updateWidget
    , growVertical
    , growHorizontal
    , render
    , handleKeyEvent
    , getState
    )
import Graphics.Vty.Widgets.Base
    ( hBox
    )
import Graphics.Vty.Widgets.Text
    ( simpleText
    )

data HBorder = HBorder Attr Char

-- |Create a single-row horizontal border.
hBorder :: (MonadIO m) => Attr -> m (Widget HBorder)
hBorder = hBorderWith '-'

-- |Create a single-row horizontal border using the specified
-- attribute and character.
hBorderWith :: (MonadIO m) => Char -> Attr -> m (Widget HBorder)
hBorderWith ch att = do
  wRef <- newWidget
  updateWidget wRef $ \w ->
      w { state = HBorder att ch
        , getGrowVertical = return False
        , getGrowHorizontal = return True
        , draw = \s mAttr -> do
                   HBorder attr _ <- get
                   let attr' = maybe attr id mAttr
                   return $ char_fill attr' ch (region_width s) 1
        }

data VBorder = VBorder Attr Char

-- |Create a single-column vertical border.
vBorder :: (MonadIO m) => Attr -> m (Widget VBorder)
vBorder = vBorderWith '|'

-- |Create a single-column vertical border using the specified
-- attribute and character.
vBorderWith :: (MonadIO m) => Char -> Attr -> m (Widget VBorder)
vBorderWith ch att = do
  wRef <- newWidget
  updateWidget wRef $ \w ->
      w { state = VBorder att ch
        , getGrowHorizontal = return False
        , getGrowVertical = return True
        , draw = \s mAttr -> do
                   VBorder attr _ <- get
                   let attr' = maybe attr id mAttr
                   return $ char_fill attr' ch 1 (region_height s)
        }

data Bordered a = Bordered Attr (Widget a)

-- |Wrap a widget in a bordering box using the specified attribute.
bordered :: (MonadIO m) => Attr -> Widget a -> m (Widget (Bordered a))
bordered att child = do
  wRef <- newWidget
  updateWidget wRef $ \w ->
      w { state = Bordered att child

        , getGrowVertical = do
            Bordered _ ch <- ask
            liftIO $ growVertical ch

        , getGrowHorizontal = do
            Bordered _ ch <- ask
            liftIO $ growHorizontal ch

        , keyEventHandler =
            \this key -> do
              Bordered _ ch <- getState this
              handleKeyEvent ch key

        , draw = drawBordered
        }

drawBordered :: DisplayRegion -> Maybe Attr -> StateT (Bordered a) IO Image
drawBordered s mAttr = do
  Bordered attr child <- get
  let attr' = maybe attr id mAttr

  -- Render the contained widget with enough room to draw borders.
  -- Then, use the size of the rendered widget to constrain the space
  -- used by the (expanding) borders.
  let constrained = DisplayRegion (region_width s - 2) (region_height s - 2)

  childImage <- render child constrained mAttr

  let adjusted = DisplayRegion (image_width childImage + 2)
                 (image_height childImage)
  corner <- simpleText attr' "+"

  hb <- hBorder attr'
  topWidget <- hBox corner =<< hBox hb corner
  topBottom <- render topWidget adjusted mAttr

  vb <- vBorder attr'
  leftRight <- render vb adjusted mAttr

  let middle = horiz_cat [leftRight, childImage, leftRight]

  return $ vert_cat [topBottom, middle, topBottom]
